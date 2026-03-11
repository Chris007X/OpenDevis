import { Controller } from "@hotwired/stimulus"

// Fetches unread notification count and shows/hides a badge.
// Usage: data-controller="notification-badge" data-notification-badge-url-value="/notifications/unread_count"
export default class extends Controller {
  static targets = ["badge"]
  static values  = { count: Number }

  connect() {
    this.render()
  }

  countValueChanged() {
    this.render()
  }

  render() {
    const count = this.countValue
    if (!this.hasBadgeTarget) return

    if (count > 0) {
      this.badgeTarget.textContent = count > 99 ? "99+" : count
      this.badgeTarget.style.display = "inline-flex"
    } else {
      this.badgeTarget.style.display = "none"
    }
  }
}
