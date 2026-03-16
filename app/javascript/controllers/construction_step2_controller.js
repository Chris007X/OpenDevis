import { Controller } from "@hotwired/stimulus"

// Handles construction step 2: room picker, surface total, save-on-back, "Autres" custom label.
export default class extends Controller {
  static targets = ["submit", "roomGroup", "roomCheckbox",
                    "countControl", "countDisplay", "roomInstances", "surfaceTotal"]

  connect() {
    this.validate()
    this.updateSurfaceTotal()
  }

  toggleRoom(event) {
    const checkbox = event.currentTarget
    const room = checkbox.dataset.room
    this._updateRoomUI(room, checkbox.checked)
    if (checkbox.checked) {
      this._renderInstances(room, 1)
    }
    this.validate()
    this.updateSurfaceTotal()
  }

  increment(event) {
    const room = event.currentTarget.dataset.room
    const current = this._getCount(room)
    if (current < 9) {
      this._setCount(room, current + 1)
      this._renderInstances(room, current + 1)
      this.updateSurfaceTotal()
    }
  }

  decrement(event) {
    const room = event.currentTarget.dataset.room
    const current = this._getCount(room)
    if (current > 1) {
      this._setCount(room, current - 1)
      this._renderInstances(room, current - 1)
      this.updateSurfaceTotal()
    }
  }

  syncSurface(event) {
    const instance = event.currentTarget.closest(".room-instance")
    if (!instance) return
    const hiddenSurface = instance.querySelector(".room-field-surface")
    if (hiddenSurface) hiddenSurface.value = event.currentTarget.value
    this.updateSurfaceTotal()
  }

  syncLabel(event) {
    const instance = event.currentTarget.closest(".room-instance")
    if (!instance) return
    const hiddenName = instance.querySelector(".room-field-name")
    if (hiddenName) hiddenName.value = event.currentTarget.value
  }

  goBack() {
    const form = this.element
    form.action = form.dataset.saveUrl
    form.requestSubmit()
  }

  updateSurfaceTotal() {
    const total = this.roomInstancesTargets
      .filter(container => !container.hidden)
      .flatMap(container => Array.from(container.querySelectorAll('input[type="number"]')))
      .reduce((sum, input) => sum + (parseFloat(input.value) || 0), 0)

    if (this.hasSurfaceTotalTarget) {
      this.surfaceTotalTarget.textContent = total % 1 === 0 ? total : total.toFixed(1)
    }
  }

  validate() {
    const checkedRooms = this.roomCheckboxTargets.filter(cb => cb.checked)
    this.submitTarget.disabled = checkedRooms.length === 0
  }

  // ── Private helpers ──────────────────────────────────────────────────

  _updateRoomUI(room, checked) {
    const countControl = this.countControlTargets.find(el => el.dataset.room === room)
    const instancesContainer = this.roomInstancesTargets.find(el => el.dataset.room === room)

    if (countControl) countControl.hidden = !checked
    if (instancesContainer) {
      instancesContainer.hidden = !checked
      if (!checked) {
        instancesContainer.innerHTML = ""
        this._setCount(room, 1)
      }
    }
  }

  _getCount(room) {
    const display = this.countDisplayTargets.find(el => el.dataset.room === room)
    return display ? parseInt(display.textContent, 10) : 1
  }

  _setCount(room, count) {
    const display = this.countDisplayTargets.find(el => el.dataset.room === room)
    if (display) display.textContent = count
  }

  _renderInstances(room, count) {
    const container = this.roomInstancesTargets.find(el => el.dataset.room === room)
    if (!container) return

    // Preserve existing surface values and custom labels (for "Autres")
    const existingSurfaces = {}
    const existingLabels = {}
    container.querySelectorAll(".room-instance").forEach((el, i) => {
      const numInput = el.querySelector('input[type="number"]')
      if (numInput && numInput.value) existingSurfaces[i] = numInput.value
      const labelInput = el.querySelector('.room-label-input')
      if (labelInput) existingLabels[i] = labelInput.value
    })

    let html = ""
    for (let i = 0; i < count; i++) {
      const surface = existingSurfaces[i] || ""

      if (room === "Autres") {
        const labelVal = existingLabels[i] || ""
        html += `
          <div class="room-instance" data-room-index>
            <input type="text" class="room-label-input"
                   placeholder="Nom de la pièce…"
                   data-action="input->construction-step2#syncLabel"
                   value="${labelVal}"
                   style="flex:1;border:1px solid #C8C4BC;border-radius:6px;padding:0.25rem 0.5rem;font-size:0.85rem;color:#2C2A25;min-width:0;background:#fff;">
            <input type="hidden" class="room-field-name" name="rooms[][name]" value="${labelVal}">
            <input type="hidden" class="room-field-base" name="rooms[][base]" value="Autres">
            <input type="hidden" class="room-field-surface" name="rooms[][surface]" value="${surface}">
            <div class="room-instance-surface">
              <input type="number" placeholder="—" min="0" step="any"
                     data-action="input->construction-step2#syncSurface"
                     value="${surface}">
              <span>m²</span>
            </div>
          </div>`
      } else {
        const label = count > 1 ? `${room} ${i + 1}` : room
        html += `
          <div class="room-instance" data-room-index>
            <div class="room-instance-name">${label}</div>
            <input type="hidden" class="room-field-name" name="rooms[][name]" value="${label}">
            <input type="hidden" class="room-field-base" name="rooms[][base]" value="${room}">
            <input type="hidden" class="room-field-surface" name="rooms[][surface]" value="${surface}">
            <div class="room-instance-surface">
              <input type="number" placeholder="—" min="0" step="any"
                     data-action="input->construction-step2#syncSurface"
                     value="${surface}">
              <span>m²</span>
            </div>
          </div>`
      }
    }

    container.innerHTML = html
    container.hidden = false
  }
}
