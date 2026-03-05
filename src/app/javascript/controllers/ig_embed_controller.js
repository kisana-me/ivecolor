import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loader"]

  connect() {
    this.contentWrapper = document.createElement("div")
    this.contentWrapper.style.opacity = "0"
    this.contentWrapper.style.height = "0px"
    this.contentWrapper.style.overflow = "hidden"
    this.contentWrapper.style.transition = "opacity 0.3s ease"

    const blockquote = this.element.querySelector("blockquote")
    if (blockquote) {
      blockquote.parentNode.insertBefore(this.contentWrapper, blockquote)
      this.contentWrapper.appendChild(blockquote)
    } else {
      this.contentWrapper = this.element.querySelector('div:not([data-ig-embed-target])')
    }

    this.injectScript()
    this.startChecking()

    this.timeout = setTimeout(() => {
      this.showContent()
    }, 10000)
  }

  disconnect() {
    this.cleanup()
  }

  injectScript() {
    if (window.instgrm) {
      window.instgrm.Embeds.process()
    } else {
      if (!document.getElementById("instagram-embed-script")) {
        const script = document.createElement("script")
        script.id = "instagram-embed-script"
        script.src = "//www.instagram.com/embed.js"
        script.async = true
        document.body.appendChild(script)
      }
    }
  }

  startChecking() {
    this.messageHandler = (event) => {
      if (typeof event.data === "string" && event.origin.includes("instagram.com")) {
        try {
          const data = JSON.parse(event.data)
          if (data && data.type === "MEASURE") {
            const iframe = this.contentWrapper.querySelector('iframe')
            if (iframe && event.source === iframe.contentWindow) {
              this.showContent()
            }
          }
        } catch(e) {}
      }
    }
    window.addEventListener("message", this.messageHandler)

    let previousHeight = 0
    let stableCount = 0

    this.checkInterval = setInterval(() => {
      if (!this.contentWrapper) return

      const iframe = this.contentWrapper.querySelector('iframe')
      if (iframe) {
        const inlineHeight = parseInt(iframe.style.height || "0", 10)

        if (inlineHeight > 250) {
          if (Math.abs(inlineHeight - previousHeight) < 5) {
            stableCount++
            if (stableCount > 15) {
              this.showContent()
            }
          } else {
            stableCount = 0
            previousHeight = inlineHeight
          }
        }
      }
    }, 100)
  }

  showContent() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.style.display = "none"
    }
    if (this.contentWrapper) {
      this.contentWrapper.style.opacity = "1"
      this.contentWrapper.style.height = ""
      this.contentWrapper.style.overflow = ""
    }

    this.cleanup()
  }

  cleanup() {
    if (this.checkInterval) {
      clearInterval(this.checkInterval)
      this.checkInterval = null
    }
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
    if (this.messageHandler) {
      window.removeEventListener("message", this.messageHandler)
      this.messageHandler = null
    }
  }
}