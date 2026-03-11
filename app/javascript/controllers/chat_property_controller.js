import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "sendBtn", "micBtn", "micIcon", "waveform"]
  static values  = { endpoint: String }

  connect() {
    this.history   = []
    this.listening = false
    this.animFrame = null
    this.setupSpeech()
  }

  disconnect() {
    this.stopRecording()
  }

  // ── Voice ──────────────────────────────────────────────────────────────────

  setupSpeech() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SR) { this.micBtnTarget.hidden = true; return }

    this.recognition                = new SR()
    this.recognition.lang           = "fr-FR"
    this.recognition.continuous     = false
    this.recognition.interimResults = true

    this.recognition.onresult = (e) => {
      this.inputTarget.value = Array.from(e.results).map(r => r[0].transcript).join("")
      this.inputChanged()
    }
    this.recognition.onend   = () => this.stopRecording()
    this.recognition.onerror = () => this.stopRecording()
  }

  async toggleMic() {
    if (this.listening) {
      this.recognition.stop()
    } else {
      await this.startRecording()
    }
  }

  async startRecording() {
    this.listening = true
    this.recognition.start()

    // Show waveform canvas, hide mic icon
    this.micIconTarget.hidden  = true
    this.waveformTarget.hidden = false
    this.micBtnTarget.title    = "Arrêter la dictée"

    // Web Audio for amplitude visualisation
    try {
      this.stream   = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.audioCtx = new AudioContext()
      this.analyser = this.audioCtx.createAnalyser()
      this.analyser.fftSize = 64
      this.audioCtx.createMediaStreamSource(this.stream).connect(this.analyser)
      this.drawWaveform()
    } catch {
      // Mic permission denied — continue without waveform, use pulse animation
      this.waveformTarget.dataset.pulse = "true"
    }
  }

  stopRecording() {
    if (!this.listening) return
    this.listening = false

    cancelAnimationFrame(this.animFrame)
    this.waveformTarget.hidden        = true
    this.waveformTarget.dataset.pulse = ""
    this.micIconTarget.hidden         = false
    this.micBtnTarget.title           = "Dicter"

    if (this.stream)   { this.stream.getTracks().forEach(t => t.stop()); this.stream = null }
    if (this.audioCtx) { this.audioCtx.close(); this.audioCtx = null }
  }

  drawWaveform() {
    const canvas = this.waveformTarget
    const ctx    = canvas.getContext("2d")
    const w      = canvas.width
    const h      = canvas.height
    const bars   = 5
    const data   = new Uint8Array(this.analyser.frequencyBinCount)

    const draw = () => {
      if (!this.listening) return
      this.animFrame = requestAnimationFrame(draw)
      this.analyser.getByteFrequencyData(data)
      ctx.clearRect(0, 0, w, h)

      const barW = 3
      const totalGap = w - bars * barW
      const gap = totalGap / (bars + 1)

      for (let i = 0; i < bars; i++) {
        // Sample from the lower half of the frequency spectrum (voice range)
        const idx     = Math.floor((i / bars) * (data.length * 0.6))
        const amp     = data[idx] / 255
        const barH    = Math.max(4, amp * h * 0.85)
        const x       = gap + i * (barW + gap)
        const y       = (h - barH) / 2

        ctx.fillStyle = "#2C2A25"
        ctx.beginPath()
        ctx.roundRect(x, y, barW, barH, 1.5)
        ctx.fill()
      }
    }
    draw()
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  inputChanged() {
    const hasText = this.inputTarget.value.trim().length > 0
    this.sendBtnTarget.classList.toggle("active", hasText)
    // Auto-grow textarea
    this.inputTarget.style.height = "auto"
    this.inputTarget.style.height = Math.min(this.inputTarget.scrollHeight, 120) + "px"
  }

  handleKeydown(e) {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); this.send() }
  }

  async send() {
    const text = this.inputTarget.value.trim()
    if (!text) return

    this.addMessage("user", text)
    this.history.push({ role: "user", content: text })
    this.inputTarget.value = ""
    this.inputChanged()
    this.setSending(true)

    try {
      const res  = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({ history: this.history })
      })
      const json = await res.json()

      this.addMessage("assistant", json.reply)
      this.history.push({ role: "assistant", content: json.reply })

      if (json.complete && json.data) this.fillFields(json.data)
    } catch {
      this.addMessage("assistant", "Une erreur est survenue. Veuillez réessayer.")
    } finally {
      this.setSending(false)
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  addMessage(role, text) {
    const div       = document.createElement("div")
    div.className   = role === "user" ? "chat-msg chat-msg--user" : "chat-msg chat-msg--assistant"
    div.textContent = text
    this.messagesTarget.appendChild(div)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  fillFields(data) {
    if (data.type_de_bien)      this.setField("project_property_url",      data.type_de_bien)
    if (data.total_surface_sqm) this.setField("project_total_surface_sqm", data.total_surface_sqm)
    if (data.room_count)        this.setField("project_room_count",         data.room_count)
    if (data.location_zip)      this.setField("project_location_zip",       data.location_zip)
    if (data.energy_rating)     this.setSelect("project_energy_rating",     data.energy_rating)
  }

  setField(id, value)  { const el = document.getElementById(id); if (el) el.value = value }

  setSelect(id, value) {
    const el = document.getElementById(id)
    if (!el) return
    const opt = [...el.options].find(o => o.value === value)
    if (opt) el.value = value
  }

  setSending(on) {
    this.sendBtnTarget.disabled    = on
    this.sendBtnTarget.textContent = on ? "..." : "Envoyer"
    this.inputTarget.disabled      = on
    if (!on) {
      this.inputTarget.style.height = "38px"
      this.sendBtnTarget.classList.remove("active")
    }
  }
}
