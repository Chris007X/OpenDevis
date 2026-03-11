import { Controller } from "@hotwired/stimulus"

// Handles URL analysis for wizard step 1:
// fetches property data from a listing URL via backend scraper + LLM,
// then pre-fills the property info form fields.
export default class extends Controller {
  static targets = ["input", "btn", "status"]
  static values  = { endpoint: String }

  async analyze() {
    const url = this.inputTarget.value.trim()
    if (!url) return

    this.btnTarget.disabled = true
    this.btnTarget.textContent = "Analyse en cours..."
    this.showStatus("loading", "Récupération de l'annonce...")

    try {
      const res = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({ url })
      })
      const json = await res.json()

      if (json.success) {
        this.fillFields(json.data)
        this.showStatus("success", "Informations pré-remplies ! Vérifiez et corrigez si besoin.")
      } else {
        this.showStatus("error", json.error)
      }
    } catch {
      this.showStatus("error", "Impossible d'analyser cette URL.")
    } finally {
      this.btnTarget.disabled = false
      this.btnTarget.textContent = "Analyser ✨"
    }
  }

  fillFields(data) {
    if (data.type_de_bien)      this.setField("project_property_url",      data.type_de_bien)
    if (data.total_surface_sqm) this.setField("project_total_surface_sqm", data.total_surface_sqm)
    if (data.room_count)        this.setField("project_room_count",         data.room_count)
    if (data.location_zip)      this.setField("project_location_zip",       data.location_zip)
    if (data.energy_rating)     this.setSelect("project_energy_rating",     data.energy_rating)
  }

  setField(id, value) {
    const el = document.getElementById(id)
    if (el) el.value = value
  }

  setSelect(id, value) {
    const el = document.getElementById(id)
    if (!el) return
    const opt = [...el.options].find(o => o.value === value)
    if (opt) el.value = value
  }

  showStatus(type, message) {
    const el = this.statusTarget
    el.hidden = false
    el.className = type === "success" ? "mt-2 text-success small"
                 : type === "error"   ? "mt-2 text-danger small"
                 : "mt-2 text-muted small"
    el.textContent = message
  }
}
