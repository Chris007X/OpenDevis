import { Controller } from "@hotwired/stimulus"

// Manages artisan selection within each category section.
// Enforces max 3 selections per section and updates the counter.
export default class extends Controller {
  static targets = ["section", "card", "checkbox", "counter", "sectionToggle"]

  connect() {
    this.sectionTargets.forEach(section => this.updateSection(section))
  }

  selectAll(event) {
    const toggle = event.currentTarget
    const section = toggle.closest("[data-artisan-select-target='section']")
    if (!section) return

    const checked = toggle.checked
    const max = parseInt(section.dataset.max || "3", 10)
    const checkboxes = [...section.querySelectorAll("input[type='checkbox']")].filter(cb => cb !== toggle)

    checkboxes.forEach((cb, i) => {
      cb.disabled = false
      cb.checked = checked ? i < max : false
    })

    this.updateSection(section)
  }

  toggle(event) {
    const checkbox = event.currentTarget
    const section = checkbox.closest("[data-artisan-select-target='section']")
    if (!section) return

    const max = parseInt(section.dataset.max || "3", 10)
    const checked = section.querySelectorAll("input[type='checkbox']:checked")

    if (checkbox.checked && checked.length > max) {
      checkbox.checked = false
    }

    this.updateSection(section)
  }

  updateSection(section) {
    const max = parseInt(section.dataset.max || "3", 10)
    const toggle = section.querySelector("[data-artisan-select-target='sectionToggle']")
    const artisanCheckboxes = [...section.querySelectorAll("input[type='checkbox']")].filter(cb => cb !== toggle)
    const checkedCount = artisanCheckboxes.filter(cb => cb.checked).length

    // Update counter
    const counter = section.querySelector("[data-artisan-select-target='counter']")
    if (counter) {
      counter.textContent = `${checkedCount} / ${max} sélectionnés`
      if (checkedCount > 0) {
        counter.classList.add("has-selection")
      } else {
        counter.classList.remove("has-selection")
      }
    }

    // Sync "Tout sélectionner" toggle
    if (toggle) {
      const selectable = Math.min(max, artisanCheckboxes.length)
      toggle.checked = selectable > 0 && checkedCount >= selectable
    }

    // Update card visual state + disable unchecked when at max
    artisanCheckboxes.forEach(cb => {
      const card = cb.closest("[data-artisan-select-target='card']")
      if (!card) return

      if (cb.checked) {
        card.classList.add("selected")
        card.classList.remove("disabled")
      } else {
        card.classList.remove("selected")
        if (checkedCount >= max) {
          card.classList.add("disabled")
          cb.disabled = true
        } else {
          card.classList.remove("disabled")
          cb.disabled = false
        }
      }
    })
  }
}
