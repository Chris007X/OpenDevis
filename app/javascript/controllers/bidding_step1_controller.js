import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["catCard", "deadline", "submitBtn"]

  connect() {
    this.updateButton()
  }

  updateButton() {
    const anyChecked = this.catCardTargets.some(card => {
      return card.querySelector('input[type="checkbox"]')?.checked
    })
    const hasDeadline = this.hasDeadlineTarget && this.deadlineTarget.value.length > 0

    const enabled = anyChecked && hasDeadline
    this.submitBtnTarget.disabled = !enabled
    this.submitBtnTarget.style.opacity = enabled ? "1" : "0.4"
    this.submitBtnTarget.style.cursor = enabled ? "pointer" : "not-allowed"
  }

  // Visual toggle for card selection state
  catCardTargets_changed() {
    this.catCardTargets.forEach(card => {
      const cb = card.querySelector('input[type="checkbox"]')
      if (cb?.checked) {
        card.classList.add("selected")
      } else {
        card.classList.remove("selected")
      }
    })
  }
}
