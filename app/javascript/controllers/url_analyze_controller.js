import { Controller } from "@hotwired/stimulus"

// Handles URL analysis for wizard step 1:
// fetches property data from a listing URL via backend scraper + LLM,
// then pre-fills the property info form fields.
export default class extends Controller {
  static targets = ["input", "btn", "status"]
  static values  = { endpoint: String }

  toggleBtn() {
    const hasValue = this.inputTarget.value.trim().length > 0
    const btn = this.btnTarget
    btn.disabled = !hasValue
    if (hasValue) {
      btn.style.cssText = "border-radius:8px;padding:0.375rem 0.85rem;font-size:0.9rem;font-weight:500;white-space:nowrap;background:#2C2A25;color:#fff;border:1px solid #2C2A25;cursor:pointer;"
    } else {
      btn.style.cssText = "border-radius:8px;padding:0.375rem 0.85rem;font-size:0.9rem;font-weight:500;white-space:nowrap;background:#C8C4BC;color:#4A4640;border:1px solid #C8C4BC;cursor:not-allowed;"
    }
  }

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
      this.btnTarget.textContent = "Analyser"
    }
  }

  fillFields(data) {
    if (data.type_de_bien)      this.setPropertyType(data.type_de_bien)
    if (data.total_surface_sqm) this.setField("project_total_surface_sqm", Math.ceil(data.total_surface_sqm))
    if (data.room_count)        this.setField("project_room_count",         data.room_count)
    if (data.location_zip)      this.setLocationZip(data.location_zip)
    if (data.energy_rating)     this.setSelect("project_energy_rating",     data.energy_rating)
    if (data.summary)           this.setField("project_description",        data.summary)
    if (data.photo_url)         document.dispatchEvent(new CustomEvent("photo:received", { detail: { url: data.photo_url } }))
    const nameField = document.getElementById("project_name")
    if (nameField && !nameField.value.trim()) nameField.value = this.buildAutoTitle(data)
    this.triggerValidation()
  }

  buildAutoTitle(data) {
    const parts = []
    if (data.type_de_bien)      parts.push(data.type_de_bien)
    if (data.location_zip)      parts.push(data.location_zip)
    if (data.total_surface_sqm) parts.push(`${Math.ceil(data.total_surface_sqm)}m²`)
    return parts.join(" ")
  }

  triggerValidation() {
    const form = document.querySelector("[data-controller~='wizard-form']")
    if (form) form.dispatchEvent(new Event("input", { bubbles: true }))
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
