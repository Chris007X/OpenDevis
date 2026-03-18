import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.poll()
    this.interval = setInterval(() => this.poll(), 30000)
    this.onResponseReceived = () => { this.poll(); this.pulse() }
    window.addEventListener("response-toast:received", this.onResponseReceived)
  }

  disconnect() {
    clearInterval(this.interval)
    window.removeEventListener("response-toast:received", this.onResponseReceived)
  }

  pulse() {
    const el = this.element.querySelector("svg") || this.element
    el.animate(
      [
        { transform: "rotate(0deg)" },
        { transform: "rotate(-18deg)" },
        { transform: "rotate(18deg)" },
        { transform: "rotate(-12deg)" },
        { transform: "rotate(12deg)" },
        { transform: "rotate(0deg)" }
      ],
      { duration: 500, easing: "ease-in-out" }
    )
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
