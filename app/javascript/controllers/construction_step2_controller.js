import { Controller } from "@hotwired/stimulus"

// Handles construction step 2: open room picker, manage room instances (+/-),
// and enable the Generate button as soon as at least one room is checked.
// No surface-vs-total validation (construction = new build).
export default class extends Controller {
  static targets = ["submit", "roomGroup", "roomCheckbox",
                    "countControl", "countDisplay", "roomInstances"]

  connect() {
    this.validate()
  }

  toggleRoom(event) {
    const checkbox = event.currentTarget
    const room = checkbox.dataset.room
    this._updateRoomUI(room, checkbox.checked)
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

  syncSurface(event) {
    const instance = event.currentTarget.closest(".room-instance")
    if (!instance) return
    const hiddenSurface = instance.querySelector(".room-field-surface")
    if (hiddenSurface) hiddenSurface.value = event.currentTarget.value
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
            <input type="number" placeholder="—" min="0" step="any"
                   data-action="input->construction-step2#syncSurface"
                   value="${surface}">
            <span>m²</span>
          </div>
        </div>`
    }

    container.innerHTML = html
    container.hidden = false
  }
}
