import { Controller } from "@hotwired/stimulus"

// Toggles import mode panels (URL / PDF / Chat) in wizard step 1.
// Clicking the same active button collapses it.
export default class extends Controller {
  static targets = ["btn", "panel"]

  toggle(event) {
    const mode     = event.currentTarget.dataset.mode
    const isActive = event.currentTarget.classList.contains("active")

    // Reset all
    this.btnTargets.forEach(b => b.classList.remove("active"))
    this.panelTargets.forEach(p => { p.hidden = true })

    // Open selected (unless already active — then just collapse)
    if (!isActive) {
      event.currentTarget.classList.add("active")
      const panel = this.panelTargets.find(p => p.dataset.mode === mode)
      if (panel) panel.hidden = false
    }
  }
}
