import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "nameDisplay"]

  show(event) {
    event.preventDefault()
    event.stopPropagation()

    const btn = event.currentTarget
    this.formTarget.action = btn.dataset.archivePath
    this.nameDisplayTarget.textContent = btn.dataset.archiveName

    bootstrap.Modal.getOrCreateInstance(this.element.querySelector("#archiveConfirmModal")).show()
  }

  confirm() {
    this.formTarget.requestSubmit()
    bootstrap.Modal.getInstance(this.element.querySelector("#archiveConfirmModal")).hide()
  }
}
