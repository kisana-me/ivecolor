import { Controller } from "@hotwired/stimulus"

let youTubeApiPromise

function loadYouTubeIframeApi() {
  if (youTubeApiPromise) return youTubeApiPromise

  youTubeApiPromise = new Promise((resolve, reject) => {
    if (window.YT && window.YT.Player) {
      resolve(window.YT)
      return
    }

    const previousReady = window.onYouTubeIframeAPIReady
    window.onYouTubeIframeAPIReady = () => {
      if (typeof previousReady === "function") previousReady()
      resolve(window.YT)
    }

    const existing = document.querySelector('script[src="https://www.youtube.com/iframe_api"]')
    if (existing) return

    const script = document.createElement("script")
    script.src = "https://www.youtube.com/iframe_api"
    script.async = true
    script.onerror = () => reject(new Error("Failed to load YouTube IFrame API"))
    document.head.appendChild(script)
  })

  return youTubeApiPromise
}

export default class extends Controller {
  static targets = ["player", "content"]
  static values = {
    videoId: String,
    cues: Array,
  }

  connect() {
    this.lastCueIndex = null
    this.timerId = null
    this.playerInstance = null
    this.onResize = () => this.applyLayout()

    loadYouTubeIframeApi()
      .then(() => this.createPlayer())
      .catch((e) => {
        console.warn(e)
      })

    this.updateContent(0)

    window.addEventListener("resize", this.onResize, { passive: true })
    this.applyLayout()
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    this.stopTimer()
    if (this.playerInstance && typeof this.playerInstance.destroy === "function") {
      this.playerInstance.destroy()
    }
  }

  createPlayer() {
    if (!this.hasPlayerTarget) return
    if (!window.YT || !window.YT.Player) return

    this.playerInstance = new window.YT.Player(this.playerTarget, {
      videoId: this.videoIdValue,
      events: {
        onReady: () => {
          this.applyLayout()
          this.startTimer()
          this.updateFromPlayer()
        },
        onStateChange: () => {
          this.updateFromPlayer()
        },
      },
    })
  }

  applyLayout() {
    if (!this.hasPlayerTarget || !this.hasContentTarget) return

    const viewportH = window.innerHeight || 0
    const maxTotalH = Math.max(0, viewportH - 100)

    const headerEl = this.element.querySelector(".yt-sync-header")
    const headerH = headerEl ? headerEl.getBoundingClientRect().height : 0
    const chrome = 3 * 2 + 2 + 28
    const available = maxTotalH - headerH - chrome

    const containerW = this.element.querySelector(".yt-sync-inner")?.clientWidth
      || this.element.clientWidth
    if (!containerW || available <= 0) return

    const desiredVideoH = (containerW * 9) / 16
    const videoMaxH = available / 2.5
    const videoH = Math.max(1, Math.floor(Math.min(desiredVideoH, videoMaxH)))
    const contentH = Math.max(1, Math.floor(available - videoH))

    this.playerTarget.style.height = `${videoH}px`
    this.playerTarget.style.width = "100%"

    const iframe = this.playerTarget.querySelector("iframe")
    if (iframe) {
      iframe.style.width = "100%"
      iframe.style.height = "100%"
      iframe.style.display = "block"
    }

    this.contentTarget.style.height = `${contentH}px`
    this.contentTarget.style.overflowY = "auto"
  }

  startTimer() {
    this.stopTimer()
    this.timerId = window.setInterval(() => {
      this.updateFromPlayer()
    }, 300)
  }

  stopTimer() {
    if (this.timerId) {
      window.clearInterval(this.timerId)
      this.timerId = null
    }
  }

  updateFromPlayer() {
    if (!this.playerInstance || typeof this.playerInstance.getCurrentTime !== "function") return
    const t = Number(this.playerInstance.getCurrentTime())
    if (Number.isNaN(t)) return
    this.updateContent(t)
  }

  updateContent(currentTimeSeconds) {
    if (!this.hasContentTarget) return

    const cues = Array.isArray(this.cuesValue) ? this.cuesValue : []
    if (cues.length === 0) {
      if (this.lastCueIndex !== -1) {
        this.contentTarget.innerHTML = ""
        this.lastCueIndex = -1
      }
      return
    }

    let index = -1
    for (let i = 0; i < cues.length; i += 1) {
      const at = Number(cues[i]?.at)
      if (!Number.isFinite(at)) continue
      if (at <= currentTimeSeconds) index = i
      else break
    }

    if (index === this.lastCueIndex) return

    const html = index >= 0 ? String(cues[index]?.html ?? "") : ""
    this.contentTarget.innerHTML = html
    this.lastCueIndex = index
  }
}
