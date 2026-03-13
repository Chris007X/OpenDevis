import { Controller } from "@hotwired/stimulus"

// Handles Step 2: show/hide room picker, manage room instances with +/- controls,
// and validate that at least 1 room is checked when "par_piece" is selected.
// Also validates that room surface sum does not exceed total project surface.
export default class extends Controller {
  static targets = ["roomPicker", "submit", "roomGroup", "roomCheckbox",
                     "countControl", "countDisplay", "roomInstances", "surfaceError"]
  static values = { totalSurface: Number }

  connect() {
    this._savedSurfaces = {}
    this.validate()
  }

  toggleRoomPicker() {
    const selected = this.element.querySelector('input[name="renovation_type"]:checked')
    const isParPiece = selected && selected.value === "par_piece"

    // Save surface values when switching away from par_piece
    if (!isParPiece) {
      this._saveSurfaces()
    } else {
      // Restore surfaces when switching back to par_piece
      this._restoreSurfaces()
    }

    this.roomPickerTarget.hidden = !isParPiece
    this.validate()
  }

  toggleRoom(event) {
    const checkbox = event.currentTarget
    const room = checkbox.dataset.room
    this._updateRoomUI(room, checkbox.checked, 1)
    if (checkbox.checked) {
      this._renderInstances(room, 1)
    }
    this.validate()
  }

  increment(event) {
    const room = event.currentTarget.dataset.room
    const current = this._getCount(room)
    if (current < 9) {
      this._setCount(room, current + 1)
      this._renderInstances(room, current + 1)
    }
  }

  decrement(event) {
    const room = event.currentTarget.dataset.room
    const current = this._getCount(room)
    if (current > 1) {
      this._setCount(room, current - 1)
      this._renderInstances(room, current - 1)
    }
  }

  validate() {
    const selected = this.element.querySelector('input[name="renovation_type"]:checked')

    if (!selected) {
      this.submitTarget.disabled = true
      this._hideSurfaceError()
      return
    }

    if (selected.value === "par_piece") {
      const checkedRooms = this.roomCheckboxTargets.filter(cb => cb.checked)
      if (checkedRooms.length === 0) {
        this.submitTarget.disabled = true
        this._hideSurfaceError()
        return
      }

      // Validate surface sum vs total project surface
      if (this.hasTotalSurfaceValue && this.totalSurfaceValue > 0) {
        const sum = this._computeSurfaceSum()
        if (sum > this.totalSurfaceValue) {
          this.submitTarget.disabled = true
          this._showSurfaceError(sum, this.totalSurfaceValue)
          return
        }
      }

      this._hideSurfaceError()
      this.submitTarget.disabled = false
    } else {
      this._hideSurfaceError()
      this.submitTarget.disabled = false
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  _updateRoomUI(room, checked, count) {
    const countControl = this.countControlTargets.find(el => el.dataset.room === room)
    const instancesContainer = this.roomInstancesTargets.find(el => el.dataset.room === room)

    if (countControl) countControl.hidden = !checked
    if (instancesContainer) {
      instancesContainer.hidden = !checked
      if (!checked) instancesContainer.innerHTML = ""
    }
    if (!checked) this._setCount(room, 1)
  }

  _getCount(room) {
    const display = this.countDisplayTargets.find(el => el.dataset.room === room)
    return display ? parseInt(display.textContent, 10) : 1
  }

  _setCount(room, count) {
    const display = this.countDisplayTargets.find(el => el.dataset.room === room)
    if (display) display.textContent = count
  }

  syncSurface(event) {
    const instance = event.currentTarget.closest(".room-instance")
    if (!instance) return
    const hiddenSurface = instance.querySelector(".room-field-surface")
    if (hiddenSurface) hiddenSurface.value = event.currentTarget.value
    this.validate()
  }

  _renderInstances(room, count) {
    const container = this.roomInstancesTargets.find(el => el.dataset.room === room)
    if (!container) return

    // Preserve existing surface values
    const existingSurfaces = {}
    container.querySelectorAll(".room-instance").forEach((el, i) => {
      const input = el.querySelector('input[type="number"]')
      if (input && input.value) existingSurfaces[i] = input.value
    })

    let html = ""
    for (let i = 0; i < count; i++) {
      const label = count > 1 ? `${room} ${i + 1}` : room
      const surface = existingSurfaces[i] || ""
      html += `
        <div class="room-instance" data-room-index>
          <div class="room-instance-name">${label}</div>
          <input type="hidden" class="room-field-name" name="rooms[][name]" value="${label}">
          <input type="hidden" class="room-field-base" name="rooms[][base]" value="${room}">
          <input type="hidden" class="room-field-surface" name="rooms[][surface]" value="${surface}">
          <div class="room-instance-surface">
            <input type="number" placeholder="—" min="0" step="0.5"
                   data-action="input->renovation-type#syncSurface"
                   value="${surface}">
            <span>m²</span>
          </div>
        </div>`
    }

    container.innerHTML = html
    container.hidden = false
  }

  _computeSurfaceSum() {
    let sum = 0
    this.element.querySelectorAll(".room-field-surface").forEach(field => {
      const val = parseFloat(field.value)
      if (!isNaN(val)) sum += val
    })
    return sum
  }

  _showSurfaceError(sum, max) {
    if (this.hasSurfaceErrorTarget) {
      this.surfaceErrorTarget.textContent = `La somme des surfaces (${sum} m²) dépasse la surface totale du bien (${max} m²)`
      this.surfaceErrorTarget.hidden = false
    }
  }

  _hideSurfaceError() {
    if (this.hasSurfaceErrorTarget) {
      this.surfaceErrorTarget.hidden = true
    }
  }

  _saveSurfaces() {
    this.element.querySelectorAll(".room-instance").forEach(instance => {
      const nameField = instance.querySelector(".room-field-name")
      const surfaceInput = instance.querySelector('input[type="number"]')
      if (nameField && surfaceInput) {
        this._savedSurfaces[nameField.value] = surfaceInput.value
      }
    })
  }

  _restoreSurfaces() {
    if (Object.keys(this._savedSurfaces).length === 0) return

    this.element.querySelectorAll(".room-instance").forEach(instance => {
      const nameField = instance.querySelector(".room-field-name")
      const surfaceInput = instance.querySelector('input[type="number"]')
      const hiddenSurface = instance.querySelector(".room-field-surface")
      if (nameField && this._savedSurfaces[nameField.value] !== undefined) {
        const val = this._savedSurfaces[nameField.value]
        if (surfaceInput) surfaceInput.value = val
        if (hiddenSurface) hiddenSurface.value = val
      }
    })
  }
}
