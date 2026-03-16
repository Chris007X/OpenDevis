import { Controller } from "@hotwired/stimulus"

// Enables/disables the submit button based on required fields being filled.
// Shows inline error messages on submit attempt when fields are invalid.
// Adds a blue border (#2663EB) to filled fields.
export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.validate()
    this.updateFilledStates()
  }

  validate() {
    const requiredFields = this.element.querySelectorAll("[data-required]")
    const allFilled = Array.from(requiredFields).every(field => {
      if (field.type === "radio") {
        const name = field.name
        return this.element.querySelector(`input[name="${name}"]:checked`) !== null
      }
      // For number fields, also check that value is non-negative
      if (field.type === "number" && field.value !== "" && parseFloat(field.value) < 0) {
        return false
      }
      // For location_zip: require exactly 5 digits
      if (field.dataset.fieldName === "location_zip") {
        const digits = field.value.replace(/\D/g, "")
        return digits.length === 5
      }
      return field.value.trim() !== ""
    })

    this.submitTarget.disabled = !allFilled
    this.updateFilledStates()
  }

  // Add blue border to filled fields
  updateFilledStates() {
    const FILLED_COLOR = "#2663EB"
    const DEFAULT_COLOR = "#C8C4BC"

    // Text, number, select fields
    this.element.querySelectorAll(".form-control, .form-select").forEach(field => {
      const isFilled = field.value && field.value.trim() !== ""
      field.style.borderColor = isFilled ? FILLED_COLOR : ""
    })

    // Radio groups (property type cards)
    this.element.querySelectorAll(".property-type-option").forEach(option => {
      const radio = option.querySelector("input[type='radio']")
      const label = option.querySelector("label")
      if (radio && label) {
        if (radio.checked) {
          label.style.borderColor = FILLED_COLOR
        } else {
          label.style.borderColor = ""
        }
      }
    })
  }

  // Show validation errors on submit attempt
  showErrors(event) {
    const requiredFields = this.element.querySelectorAll("[data-required]")
    let hasError = false

    requiredFields.forEach(field => {
      // Find the closest wrapper and any existing inline error
      const wrapper = field.closest(".col-12, .col-md-6, [data-controller='city-autocomplete']")?.closest(".col-12, .col-md-6") ||
                      field.closest(".col-12, .col-md-6")
      if (!wrapper) return

      let isEmpty = false
      if (field.type === "radio") {
        const name = field.name
        isEmpty = this.element.querySelector(`input[name="${name}"]:checked`) === null
        // Only check once per radio group
        if (wrapper.querySelector(".field-error-js")) return
      } else if (field.type === "number") {
        isEmpty = field.value.trim() === "" || parseFloat(field.value) <= 0
      } else {
        isEmpty = field.value.trim() === ""
      }

      // Remove previous JS errors
      wrapper.querySelectorAll(".field-error-js").forEach(el => el.remove())

      if (isEmpty) {
        hasError = true
        const errorDiv = document.createElement("div")
        errorDiv.className = "field-error field-error-js"
        errorDiv.textContent = this.errorMessageFor(field)
        wrapper.appendChild(errorDiv)
      }
    })

    if (hasError) {
      event.preventDefault()
      // Scroll to first error
      const firstError = this.element.querySelector(".field-error-js")
      if (firstError) {
        firstError.scrollIntoView({ behavior: "smooth", block: "center" })
      }
    }
  }

  errorMessageFor(field) {
    const name = field.name || field.dataset.fieldName || ""
    if (name.includes("property_type")) return "Veuillez sélectionner un type de bien"
    if (name.includes("total_surface_sqm") || field.type === "number") return "Veuillez renseigner la surface (nombre positif)"
    if (name.includes("location_zip")) return "Veuillez saisir un code postal valide (5 chiffres)"
    return "Ce champ est obligatoire"
  }

  // Clear JS errors when user interacts
  clearError(event) {
    const wrapper = event.target.closest(".col-12, .col-md-6")
    if (wrapper) {
      wrapper.querySelectorAll(".field-error-js").forEach(el => el.remove())
    }
  }
}
