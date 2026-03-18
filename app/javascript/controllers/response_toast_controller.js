import { Controller } from "@hotwired/stimulus"

// Animated toast that pops in from the notification badge area (top-right).
// Dispatches "response-toast:received" so the notification-badge controller can pulse.
export default class extends Controller {
  static values = {
    artisan: String,
    category: String,
    price: Number
  }

  connect() {
    this.animateIn()
    this.autoDismissTimer = setTimeout(() => this.dismiss(), 6000)

    // Let the notification badge know a new response arrived so it can pulse
    window.dispatchEvent(new CustomEvent("response-toast:received"))
  }

  disconnect() {
    clearTimeout(this.autoDismissTimer)
  }

  animateIn() {
    // Start: small, near badge (top-right). End: full toast below navbar.
    this.element.animate(
      [
        { opacity: 0, transform: "scale(0.3)", transformOrigin: "top right" },
        { opacity: 1, transform: "scale(1.03)", transformOrigin: "top right", offset: 0.7 },
        { opacity: 1, transform: "scale(1)",    transformOrigin: "top right" }
      ],
      { duration: 380, easing: "cubic-bezier(0.34, 1.56, 0.64, 1)", fill: "forwards" }
    )
  }

  dismiss() {
    clearTimeout(this.autoDismissTimer)
    const anim = this.element.animate(
      [
        { opacity: 1, transform: "scale(1)",    transformOrigin: "top right" },
        { opacity: 0, transform: "scale(0.85)", transformOrigin: "top right" }
      ],
      { duration: 200, easing: "ease-in", fill: "forwards" }
    )
    anim.onfinish = () => this.element.remove()
  }
}
