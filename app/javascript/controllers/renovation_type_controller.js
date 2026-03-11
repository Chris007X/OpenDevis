import { Controller } from "@hotwired/stimulus"

// Handles Step 2: show/hide room picker, toggle room detail fields,
// and validate that at least 1 room is checked when "par_piece" is selected.
export default class extends Controller {
  static targets = ["roomPicker", "submit", "roomDetail"]

  connect() {
    this.validate()
  }

  toggleRoomPicker() {
    const selected = this.element.querySelector('input[name="renovation_type"]:checked')
    const isParPiece = selected && selected.value === "par_piece"
    this.roomPickerTarget.hidden = !isParPiece

    // Uncheck all rooms when switching away from par_piece
    if (!isParPiece) {
      this.roomPickerTarget.querySelectorAll('input[type="checkbox"]').forEach(cb => {
        cb.checked = false
        this.toggleRoomFields({ currentTarget: cb })
      })
    }

    this.validate()
  }

  toggleRoomFields(event) {
    const checkbox = event.currentTarget
    const roomName = checkbox.value
    const detail = this.roomDetailTargets.find(el => el.dataset.room === roomName)
    if (detail) {
      detail.hidden = !checkbox.checked
      // Reset fields when unchecked
      if (!checkbox.checked) {
        detail.querySelectorAll("select").forEach(s => s.selectedIndex = 0)
      }
    }
    this.validate()
  }

  validate() {
    const selected = this.element.querySelector('input[name="renovation_type"]:checked')

    if (!selected) {
      this.submitTarget.disabled = true
      return
    }

    if (selected.value === "par_piece") {
      const checkedRooms = this.roomPickerTarget.querySelectorAll('input[type="checkbox"]:checked')
      this.submitTarget.disabled = checkedRooms.length === 0
    } else {
      this.submitTarget.disabled = false
    }
  }
}
