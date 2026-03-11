import { Controller } from "@hotwired/stimulus"

// Enables/disables the submit button based on required fields being filled
export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.validate()
  }

  validate() {
    const requiredFields = this.element.querySelectorAll("[data-required]")
    const allFilled = Array.from(requiredFields).every(field => {
      if (field.type === "radio") {
        const name = field.name
        return this.element.querySelector(`input[name="${name}"]:checked`) !== null
      }
      return field.value.trim() !== ""
    })

    this.submitTarget.disabled = !allFilled
  }
}
