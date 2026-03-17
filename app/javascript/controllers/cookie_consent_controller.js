import { Controller } from "@hotwired/stimulus"

const COOKIE_NAME = "cookie_consent"
const COOKIE_DAYS = 395 // 13 months per CNIL guidelines

export default class extends Controller {
  static targets = ["banner", "modal", "analyticsToggle", "marketingToggle"]

  connect() {
    this._handleReopen = () => this.reopenBanner()
    window.addEventListener("cookie-consent:reopen", this._handleReopen)

    const consent = this._readConsent()
    if (consent) {
      // Consent already given — ensure analytics state matches
      if (window.Analytics) window.Analytics.enableIfConsented()
    } else {
      // No consent cookie — show banner
      this.bannerTarget.classList.remove("d-none")
    }
  }

  disconnect() {
    window.removeEventListener("cookie-consent:reopen", this._handleReopen)
  }

  acceptAll() {
    this._saveConsent({ analytics: true, marketing: true })
    this._hideBanner()
    if (window.Analytics) window.Analytics.enableIfConsented()
  }

  rejectAll() {
    this._saveConsent({ analytics: false, marketing: false })
    this._hideBanner()
    this._closeModal()
    if (window.Analytics) window.Analytics.disable()
  }

  customize() {
    const consent = this._readConsent() || { analytics: false, marketing: false }
    this.analyticsToggleTarget.checked = consent.analytics || false
    this.marketingToggleTarget.checked = consent.marketing || false
    bootstrap.Modal.getOrCreateInstance(this.modalTarget).show()
  }

  savePreferences() {
    const prefs = {
      analytics: this.analyticsToggleTarget.checked,
      marketing: this.marketingToggleTarget.checked,
    }
    this._saveConsent(prefs)
    this._closeModal()
    this._hideBanner()

    if (window.Analytics) {
      if (prefs.analytics) {
        window.Analytics.enableIfConsented()
      } else {
        window.Analytics.disable()
      }
    }
  }

  reopenBanner() {
    this.bannerTarget.classList.remove("d-none")
  }

  // ── Private ──────────────────────────────────────────────────────────────

  _readConsent() {
    const match = document.cookie.match(/(?:^|;\s*)cookie_consent=([^;]*)/)
    if (!match) return null
    try { return JSON.parse(decodeURIComponent(match[1])) }
    catch { return null }
  }

  _saveConsent(prefs) {
    const value = encodeURIComponent(JSON.stringify({
      ...prefs,
      consented_at: new Date().toISOString(),
    }))
    const expires = new Date(Date.now() + COOKIE_DAYS * 24 * 60 * 60 * 1000).toUTCString()
    const secure = location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `${COOKIE_NAME}=${value}; expires=${expires}; path=/; SameSite=Lax${secure}`
  }

  _hideBanner() {
    this.bannerTarget.classList.add("d-none")
  }

  _closeModal() {
    const instance = bootstrap.Modal.getInstance(this.modalTarget)
    if (instance) instance.hide()
  }
}
