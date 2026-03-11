import { Controller } from "@hotwired/stimulus"

// Toggles visibility of the "autre" free-text field based on property type selection
export default class extends Controller {
  static targets = ["autreField"]

  toggle(event) {
    const value = event.currentTarget.value
    this.autreFieldTarget.hidden = value !== "autre"
    if (value !== "autre") {
      this.autreFieldTarget.querySelector("input").value = ""
    }
  }
}
