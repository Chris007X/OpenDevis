import { Controller } from "@hotwired/stimulus"

// Handles Step 2: show/hide room picker, manage room instances with +/- controls,
// and validate that at least 1 room is checked when "par_piece" is selected.
export default class extends Controller {
  static targets = ["roomPicker", "submit", "roomGroup", "roomCheckbox",
                     "countControl", "countDisplay", "roomInstances"]

  connect() {
    this.validate()
  }

  toggleRoomPicker() {
    const selected = this.element.querySelector('input[name="renovation_type"]:checked')
    const isParPiece = selected && selected.value === "par_piece"
    this.roomPickerTarget.hidden = !isParPiece

    // Don't uncheck rooms when switching away — preserve selections
    // so they are restored when user switches back to par_piece.

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
      return
    }

    if (selected.value === "par_piece") {
      const checkedRooms = this.roomCheckboxTargets.filter(cb => cb.checked)
      this.submitTarget.disabled = checkedRooms.length === 0
    } else {
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
}
