import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["catCard", "deadline", "submitBtn", "selectAllToggle"]

  connect() {
    this.catCardTargets.forEach(card => {
      const cb = card.querySelector('input[type="checkbox"]')
      if (cb?.checked) card.classList.add("selected")
    })
    this.updateButton()
    this.syncSelectAllToggle()
  }

  selectAll() {
    const checked = this.selectAllToggleTarget.checked
    const checkboxes = this.catCardTargets.map(card => card.querySelector('input[type="checkbox"]')).filter(Boolean)
    checkboxes.forEach(cb => { cb.checked = checked })
    this.catCardTargets.forEach(card => {
      card.classList.toggle("selected", checked)
    })
    this.updateButton()
  }

  syncSelectAllToggle() {
    if (!this.hasSelectAllToggleTarget) return
    const checkboxes = this.catCardTargets.map(card => card.querySelector('input[type="checkbox"]')).filter(Boolean)
    const all = checkboxes.length
    const checked = checkboxes.filter(cb => cb.checked).length
    this.selectAllToggleTarget.checked = all > 0 && checked === all
  }

  updateButton() {
    this.catCardTargets.forEach(card => {
      const cb = card.querySelector('input[type="checkbox"]')
      card.classList.toggle("selected", cb?.checked ?? false)
    })

    const anyChecked = this.catCardTargets.some(card => {
      return card.querySelector('input[type="checkbox"]')?.checked
    })
    const hasDeadline = this.hasDeadlineTarget && this.deadlineTarget.value.length > 0

    const enabled = anyChecked && hasDeadline
    this.submitBtnTarget.disabled = !enabled
    this.submitBtnTarget.style.opacity = enabled ? "1" : "0.4"
    this.submitBtnTarget.style.cursor = enabled ? "pointer" : "not-allowed"
    this.syncSelectAllToggle()
  }

}

