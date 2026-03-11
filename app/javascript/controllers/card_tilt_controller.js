import { Controller } from "@hotwired/stimulus"

// Mouse-tracking 3D tilt for the hero card stack.
// Perspective is set on the parent (.hero-card-float) so that preserve-3d
// on the stack + cards lets text children with translateZ genuinely pop out.
export default class extends Controller {
  connect() {
    // Set perspective on the parent so the child's preserve-3d context works correctly
    this.element.parentElement.style.perspective = "900px"
  }

  disconnect() {
    this.element.parentElement.style.perspective = ""
  }

  mouseenter() {
    this.element.style.transition = "transform 0.15s ease"
  }

  mousemove(e) {
    const rect  = this.element.getBoundingClientRect()
    const cx    = rect.left + rect.width  / 2
    const cy    = rect.top  + rect.height / 2
    const dx    = (e.clientX - cx) / (rect.width  / 2) // -1 → +1
    const dy    = (e.clientY - cy) / (rect.height / 2)
    const tiltX = -dy * 12
    const tiltY =  dx * 12
    this.element.style.transform = `rotateX(${tiltX}deg) rotateY(${tiltY}deg)`
  }

  mouseleave() {
    this.element.style.transition = "transform 0.6s ease"
    this.element.style.transform  = ""
    setTimeout(() => { this.element.style.transition = "" }, 650)
  }
}
