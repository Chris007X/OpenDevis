import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "preview", "previewImage", "fileInput", "status"]
  static values  = { uploadUrl: String }

  connect() {
    this._handleExternalPhoto = (e) => this.showPhoto(e.detail.url, true)
    document.addEventListener("photo:received", this._handleExternalPhoto)
  }

  disconnect() {
    document.removeEventListener("photo:received", this._handleExternalPhoto)
  }

  // ── Drag & drop ────────────────────────────────────────────────────────────

  dragover(e) {
    e.preventDefault()
    this.dropzoneTarget.classList.add("drag-over")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("drag-over")
  }

  drop(e) {
    e.preventDefault()
    this.dropzoneTarget.classList.remove("drag-over")
    const file = e.dataTransfer.files[0]
    if (file) this.handleFile(file)
  }

  // ── Click to open file picker ──────────────────────────────────────────────

  openPicker(e) {
    // Prevent triggering if user clicked the remove button
    if (e.target.closest("[data-action*='photo-upload#remove']")) return
    this.fileInputTarget.click()
  }

  fileSelected(e) {
    const file = e.target.files[0]
    if (file) this.handleFile(file)
  }

  // ── Remove photo ───────────────────────────────────────────────────────────

  remove() {
    this.previewImageTarget.src = ""
    this.photoUrlInput.value = ""
    this.fileInputTarget.value = ""
    this.previewTarget.classList.add("d-none")
    this.dropzoneTarget.classList.remove("d-none")
    this.setStatus("")
  }

  // ── Core logic ─────────────────────────────────────────────────────────────

  handleFile(file) {
    const allowed = ["image/jpeg", "image/png", "image/webp", "image/gif"]
    if (!allowed.includes(file.type)) {
      this.setStatus("Format non supporté. Utilisez JPG, PNG, WEBP ou GIF.", true)
      return
    }
    if (file.size > 5 * 1024 * 1024) {
      this.setStatus("Fichier trop grand (max 5 Mo).", true)
      return
    }

    // Instant local preview via FileReader
    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewImageTarget.src = e.target.result
      this.showDropzoneFalse()
    }
    reader.readAsDataURL(file)

    // Upload to server to get a permanent URL
    this.uploadFile(file)
  }

  uploadFile(file) {
    this.setStatus("Envoi en cours…")
    this.setSubmitDisabled(true)
    const formData = new FormData()
    formData.append("photo", file)
    formData.append("authenticity_token", this.csrfToken())

    fetch(this.uploadUrlValue, { method: "POST", body: formData })
      .then((r) => r.json())
      .then((data) => {
        if (data.photo_url) {
          this.photoUrlInput.value = data.photo_url
          this.setStatus("")
        } else {
          this.setStatus(data.error || "Erreur lors de l'envoi.", true)
        }
      })
      .catch(() => {
        this.setStatus("Erreur réseau lors de l'envoi.", true)
      })
      .finally(() => {
        this.setSubmitDisabled(false)
      })
  }

  // Called via custom event from URL/PDF analyzers
  showPhoto(url, store = true) {
    if (!url) return
    this.previewImageTarget.src = url
    if (store) this.photoUrlInput.value = url
    this.showDropzoneFalse()
    this.setStatus("")
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  showDropzoneFalse() {
    this.dropzoneTarget.classList.add("d-none")
    this.previewTarget.classList.remove("d-none")
  }

  setStatus(msg, isError = false) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget
    el.textContent = msg
    el.classList.toggle("d-none", !msg)
    el.classList.toggle("text-danger", isError)
    el.classList.toggle("text-muted", !isError)
  }

  setSubmitDisabled(disabled) {
    const submit = document.querySelector("[data-wizard-form-target='submit']")
    if (submit) submit.disabled = disabled
  }

  get photoUrlInput() {
    return document.querySelector("input[name='project[photo_url]']")
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
