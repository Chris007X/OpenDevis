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

  // ── Click tracking via data-track-event ───────────────────────────────────

  function handleClick(event) {
    const el = event.target.closest('[data-track-event]')
    if (!el) return

    const eventName = el.dataset.trackEvent
    const props = {}

    // Collect all data-track-* attributes as properties
    Object.keys(el.dataset).forEach((key) => {
      if (key.startsWith('track') && key !== 'trackEvent') {
        // camelCase → snake_case: trackProjectId → project_id
        const prop = key.replace('track', '').replace(/([A-Z])/g, '_$1').toLowerCase().replace(/^_/, '')
        props[prop] = el.dataset[key]
      }
    })

    send(eventName, props, { completed: el.dataset.trackCompleted === 'true' })
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

    // Unhandled JS errors
    window.addEventListener('error', handleError)
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
