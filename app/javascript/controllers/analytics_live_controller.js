import { Controller } from "@hotwired/stimulus"

// Polls /analytics/active_users every 10 seconds and replaces the frame content.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 10000 } }

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async refresh() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
      })
      if (!response.ok) return
      const html = await response.text()
      this.element.innerHTML = html
    } catch (_e) {
      // Network error — silently ignore, try again next interval
    }
  }
}
