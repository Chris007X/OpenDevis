import { Controller } from "@hotwired/stimulus"

// Toggles all category checkboxes within the controller scope.
// Usage:
//   <div data-controller="select-all">
//     <input type="checkbox" data-select-all-target="toggle" data-action="change->select-all#toggleAll">
//     <input type="checkbox" data-select-all-target="item" data-action="change->select-all#updateToggle">
//     ...
//   </div>
export default class extends Controller {
  static targets = ["toggle", "item"]

  toggleAll() {
    const checked = this.toggleTarget.checked
    this.itemTargets.forEach(cb => { cb.checked = checked })
  }

  updateToggle() {
    const all = this.itemTargets.length
    const checked = this.itemTargets.filter(cb => cb.checked).length
    this.toggleTarget.checked = all > 0 && checked === all
  }

  // Set initial state on connect
  connect() {
    if (this.hasToggleTarget) {
      this.updateToggle()
    }
  }
}
