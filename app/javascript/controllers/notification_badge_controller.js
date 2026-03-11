import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.poll()
    this.interval = setInterval(() => this.poll(), 30000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  async poll() {
    try {
      const response = await fetch("/notifications?format=json", {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      const unread = data.unread_count

      if (!this.hasCountTarget) return

      if (unread > 0) {
        this.countTarget.textContent = unread > 9 ? "9+" : unread
        this.countTarget.style.display = "inline-flex"
      } else {
        this.countTarget.style.display = "none"
      }
    } catch (_e) {
      // Network error, ignore silently
    }
  }
}
