import { Controller } from "@hotwired/stimulus"

// Autocomplete for French postal codes using geo.api.gouv.fr
// Triggers after 2 digits typed. Display format: "Paris (75001)"
export default class extends Controller {
  static targets = ["input", "hidden", "results"]

  connect() {
    this.timeout = null
    this.justSelected = false
    this.handleClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }

  // Strip non-digit characters from the input
  filterDigits() {
    const pos = this.inputTarget.selectionStart
    const before = this.inputTarget.value
    const filtered = before.replace(/\D/g, "")
    if (before !== filtered) {
      this.inputTarget.value = filtered
      // Restore cursor position accounting for removed chars
      const diff = before.length - filtered.length
      this.inputTarget.setSelectionRange(pos - diff, pos - diff)
    }
  }

  search() {
    clearTimeout(this.timeout)

    // Skip search if a selection was just made (avoids re-opening the dropdown)
    if (this.justSelected) {
      this.justSelected = false
      return
    }

    const raw = this.inputTarget.value.trim()

    // Clear hidden field — user must select from suggestions to validate
    this.hiddenTarget.value = ""

    // Extract digits only to decide when to trigger search
    const digits = raw.replace(/\D/g, "")

    if (digits.length < 2) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => this.fetchResults(digits), 250)
  }

  async fetchResults(digits) {
    // Use codePostal param for exact 5-digit codes, otherwise search by department prefix
    let url
    if (digits.length === 5) {
      url = `https://geo.api.gouv.fr/communes?codePostal=${digits}&fields=nom,codesPostaux&limit=10`
    } else {
      // Search communes whose postal code starts with these digits
      url = `https://geo.api.gouv.fr/departements/${digits}/communes?fields=nom,codesPostaux&limit=20`
    }

    try {
      const response = await fetch(url)
      if (!response.ok) return
      const communes = await response.json()
      this.displayResults(communes, digits)
    } catch {
      this.hideResults()
    }
  }

  displayResults(communes, digits) {
    if (communes.length === 0) {
      this.hideResults()
      return
    }

    // Build list of "Ville (CP)" entries, filtering postal codes that match typed digits
    const items = communes.flatMap(commune =>
      commune.codesPostaux
        .filter(cp => cp.startsWith(digits))
        .map(cp => ({
          label: `${commune.nom} (${cp})`,
          value: `${commune.nom} (${cp})`
        }))
    )

    // If searching by department (2-4 digits), all postal codes match — show them all
    const finalItems = items.length > 0 ? items : communes.flatMap(commune =>
      commune.codesPostaux.map(cp => ({
        label: `${commune.nom} (${cp})`,
        value: `${commune.nom} (${cp})`
      }))
    )

    const uniqueItems = finalItems.slice(0, 10)

    if (uniqueItems.length === 0) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = uniqueItems.map(item =>
      `<button type="button" class="autocomplete-item" data-action="click->city-autocomplete#select" data-value="${item.value}">${item.label}</button>`
    ).join("")

    this.resultsTarget.hidden = false
  }

  select(event) {
    const value = event.currentTarget.dataset.value
    this.justSelected = true
    this.inputTarget.value = value
    this.hiddenTarget.value = value
    this.hideResults()
    // Dispatch input event to trigger wizard-form validation
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  hideResults() {
    this.resultsTarget.hidden = true
    this.resultsTarget.innerHTML = ""
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }
}
