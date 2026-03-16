/**
 * OpenDevis Analytics — client-side event tracker.
 *
 * Sends events to POST /analytics/events via fetch({ keepalive: true })
 * so beacons survive page unloads.
 *
 * Auto-tracks:
 *   - page_view     on every turbo:load (Turbo navigation + initial load)
 *   - time_on_page  on turbo:before-visit / visibilitychange (hidden)
 *   - click         on elements with data-track-event attribute
 *   - js_error      on unhandled JS errors
 *
 * Manual tracking (from Stimulus controllers or inline scripts):
 *   Analytics.track('form_submit', { step: 4, standing: 'premium' })
 */

const Analytics = (() => {
  const ENDPOINT = '/analytics/events'
  let pageEnteredAt = null

  // ── Helpers ──────────────────────────────────────────────────────────────

  function csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content ?? ''
  }

  function send(eventType, properties = {}, extra = {}) {
    const payload = {
      authenticity_token: csrfToken(),
      event: {
        event_type: eventType,
        page_path: window.location.pathname,
        referrer: document.referrer || null,
        page_load_time_ms: extra.page_load_time_ms ?? null,
        completed: extra.completed ?? false,
        properties: {
          ...properties,
          url: window.location.href,
        },
      },
    }

    // keepalive: true lets the request outlive the current page (like sendBeacon)
    fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken(),
      },
      body: JSON.stringify(payload),
      keepalive: true,
    }).catch(() => {
      // Silently ignore — analytics must never break the app
    })
  }

  // ── Page view ─────────────────────────────────────────────────────────────

  function trackPageView() {
    pageEnteredAt = Date.now()

    // Capture Navigation Timing if available (first load only; Turbo navigations
    // don't get accurate NT entries so we skip for those)
    let loadTime = null
    if (performance?.timing) {
      const { domContentLoadedEventEnd, navigationStart } = performance.timing
      if (domContentLoadedEventEnd > 0 && navigationStart > 0) {
        loadTime = domContentLoadedEventEnd - navigationStart
      }
    }

    send('page_view', {}, { page_load_time_ms: loadTime })
  }

  // ── Time on page ──────────────────────────────────────────────────────────

  function trackTimeOnPage() {
    if (!pageEnteredAt) return
    const duration = Math.round((Date.now() - pageEnteredAt) / 1000)
    if (duration < 1) return

    send('time_on_page', { duration_seconds: duration })
    pageEnteredAt = null
  }

  // ── Click tracking ────────────────────────────────────────────────────────
  // Records ALL clicks with coordinates (for heatmap) plus optional
  // data-track-event attributes for named events.

  function elementLabel(el) {
    // Build a short human-readable label: text content or tag+class
    const text = (el.innerText || el.value || el.title || el.alt || '').trim().slice(0, 60)
    if (text) return text
    const tag = el.tagName.toLowerCase()
    const cls = el.className && typeof el.className === 'string'
      ? '.' + el.className.trim().split(/\s+/).slice(0, 2).join('.')
      : ''
    return `${tag}${cls}`
  }

  function handleClick(event) {
    const target = event.target
    const tagged = target.closest('[data-track-event]')

    // Always record a heatmap_click with coordinates and element info
    send('heatmap_click', {
      x: event.clientX,
      y: event.clientY,
      // Coordinates as percentage of viewport (stable across window sizes)
      x_pct: Math.round((event.clientX / window.innerWidth)  * 1000) / 10,
      y_pct: Math.round((event.clientY / window.innerHeight) * 1000) / 10,
      element: elementLabel(target),
      tag: target.tagName.toLowerCase(),
      href: target.closest('a')?.getAttribute('href') ?? null,
    })

    // If a data-track-event element was clicked, also fire the named event
    if (!tagged) return
    const props = {}
    Object.keys(tagged.dataset).forEach((key) => {
      if (key.startsWith('track') && key !== 'trackEvent') {
        const prop = key.replace('track', '').replace(/([A-Z])/g, '_$1').toLowerCase().replace(/^_/, '')
        props[prop] = tagged.dataset[key]
      }
    })
    send(tagged.dataset.trackEvent, props, { completed: tagged.dataset.trackCompleted === 'true' })
  }

  // ── JS error tracking ─────────────────────────────────────────────────────

  function handleError(event) {
    send('js_error', {
      message: event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
    })
  }

  function handleUnhandledRejection(event) {
    const reason = event.reason
    send('js_error', {
      message: reason instanceof Error ? reason.message : String(reason),
      type: 'unhandled_promise_rejection',
      stack: reason instanceof Error ? (reason.stack ?? null) : null,
    })
  }

  // ── Turbo-aware lifecycle ─────────────────────────────────────────────────

  function init() {
    // Track page view on every Turbo navigation (and initial load)
    document.addEventListener('turbo:load', trackPageView)

    // Track time on page before Turbo navigates away
    document.addEventListener('turbo:before-visit', trackTimeOnPage)

    // Also track when tab becomes hidden (user switches tab / closes browser)
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') trackTimeOnPage()
    })

    // Click tracking — single delegated listener on the document
    document.addEventListener('click', handleClick)

    // Unhandled JS errors and promise rejections
    window.addEventListener('error', handleError)
    window.addEventListener('unhandledrejection', handleUnhandledRejection)
  }

  // ── Public API ────────────────────────────────────────────────────────────

  return {
    init,
    track: send,
  }
})()

Analytics.init()
export default Analytics

// Expose globally so Stimulus controllers and inline scripts can call
// Analytics.track('event_name', { ... }) without importing the module
window.Analytics = Analytics
