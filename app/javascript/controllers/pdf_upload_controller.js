import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "fileInput", "filename", "fileRow", "analyzeBtn", "status"]
  static values  = { endpoint: String }

  // ── Drag & Drop ────────────────────────────────────────────────────────────

  dragover(e) {
    e.preventDefault()
    this.dropzoneTarget.classList.add("dragover")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("dragover")
  }

  drop(e) {
    e.preventDefault()
    this.dropzoneTarget.classList.remove("dragover")
    const file = e.dataTransfer.files[0]
    if (file) this.selectFile(file)
  }

  // ── File picker ────────────────────────────────────────────────────────────

  openPicker() {
    this.fileInputTarget.click()
  }

  fileSelected() {
    const file = this.fileInputTarget.files[0]
    if (file) this.selectFile(file)
  }

  selectFile(file) {
    if (!file.name.toLowerCase().endsWith(".pdf")) {
      this.showStatus("error", "Seuls les fichiers PDF sont acceptés.")
      return
    }
    if (file.size > 10 * 1024 * 1024) {
      this.showStatus("error", "Fichier trop volumineux (max 10 Mo).")
      return
    }
    this.selectedFile = file
    this.filenameTarget.textContent = file.name
    this.fileRowTarget.style.setProperty("display", "flex", "important")
    this.setAnalyzeActive(true)
    this.showStatus("", "")
  }

  remove() {
    this.selectedFile               = null
    this.fileInputTarget.value      = ""
    this.fileRowTarget.style.setProperty("display", "none", "important")
    this.filenameTarget.textContent = ""
    this.setAnalyzeActive(false)
    this.showStatus("", "")
  }

  // ── Upload & analyze ───────────────────────────────────────────────────────

  async analyze() {
    if (!this.selectedFile) return

    const form = new FormData()
    form.append("file", this.selectedFile)

    this.setLoading(true)
    this.showStatus("loading", "Extraction du document en cours...")

    try {
      const res  = await fetch(this.endpointValue, {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content },
        body: form
      })
      const json = await res.json()

      if (json.success) {
        this.fillFields(json.data)
        this.showStatus("success", "Informations pré-remplies ! Vérifiez et corrigez si besoin.")
      } else {
        this.showStatus("error", json.error)
      }
    } catch {
      this.showStatus("error", "Impossible d'analyser ce fichier.")
    } finally {
      this.setLoading(false)
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  fillFields(data) {
    if (data.type_de_bien)      this.setPropertyType(data.type_de_bien)
    if (data.total_surface_sqm) this.setField("project_total_surface_sqm", data.total_surface_sqm)
    if (data.room_count)        this.setField("project_room_count",         data.room_count)
    if (data.location_zip)      this.setLocationZip(data.location_zip)
    if (data.energy_rating)     this.setSelect("project_energy_rating",     data.energy_rating)
    if (data.summary)           this.setField("project_description",        data.summary)
  }

  setPropertyType(value) {
    const normalized = value.toLowerCase().trim()
    if (normalized === "appartement") {
      document.getElementById("property_type_appartement")?.click()
    } else if (normalized === "maison") {
      document.getElementById("property_type_maison")?.click()
    } else {
      document.getElementById("property_type_autre")?.click()
      const autreInput = document.querySelector("input[name='project[property_type_autre]']")
      if (autreInput) autreInput.value = value
    }
  }

  setLocationZip(value) {
    const visible = document.querySelector("[data-city-autocomplete-target='input']")
    const hidden  = document.querySelector("input[name='project[location_zip]']")
    if (visible) visible.value = value
    if (hidden)  hidden.value  = value
  }

  setField(id, value)  { const el = document.getElementById(id); if (el) el.value = value }

  setSelect(id, value) {
    const el = document.getElementById(id)
    if (!el) return
    const opt = [...el.options].find(o => o.value === value)
    if (opt) el.value = value
  }

  showStatus(type, msg) {
    const el     = this.statusTarget
    el.hidden    = !msg
    el.className = type === "success" ? "mt-2 small text-success"
                 : type === "error"   ? "mt-2 small text-danger"
                 : "mt-2 small text-muted"
    el.textContent = msg
  }

  setAnalyzeActive(active) {
    const btn = this.analyzeBtnTarget
    btn.disabled = !active
    if (active) {
      btn.style.background  = "#2C2A25"
      btn.style.color       = "#fff"
      btn.style.borderColor = "#2C2A25"
      btn.style.cursor      = "pointer"
    } else {
      btn.style.background  = "#E8E4DC"
      btn.style.color       = "#9B9588"
      btn.style.borderColor = "#E8E4DC"
      btn.style.cursor      = "not-allowed"
    }
  }

  setLoading(on) {
    this.analyzeBtnTarget.disabled    = on
    this.analyzeBtnTarget.textContent = on ? "Analyse en cours..." : "Analyser ✨"
    this.analyzeBtnTarget.style.opacity = on ? "0.6" : "1"
  }
}
