import { Controller } from "@hotwired/stimulus"

// Switches between room panels in step 3 "par pièce" mode
export default class extends Controller {
  static targets = ["tab", "panel"]

  switch(event) {
    event.preventDefault()
    const room = event.currentTarget.dataset.room

    this.tabTargets.forEach(tab => {
      tab.classList.toggle("active", tab.dataset.room === room)
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("active", panel.dataset.room === room)
    })
  }
}
