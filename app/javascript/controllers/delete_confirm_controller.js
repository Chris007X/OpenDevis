import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "nameDisplay"]
  static values = { csrfToken: String }

  show(event) {
    event.preventDefault()
    event.stopPropagation()

    const btn = event.currentTarget
    const path = btn.dataset.deletePath
    const name = btn.dataset.deleteName

    this.formTarget.action = path
    this.nameDisplayTarget.textContent = name

    bootstrap.Modal.getOrCreateInstance(this.element.querySelector("#deleteConfirmModal")).show()
  }

  confirm() {
    this.formTarget.requestSubmit()
    bootstrap.Modal.getInstance(this.element.querySelector("#deleteConfirmModal")).hide()
  }
}
