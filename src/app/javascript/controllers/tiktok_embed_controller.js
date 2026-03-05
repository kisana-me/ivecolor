import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loader"]

  connect() {
    this.injectScript()
    this.startChecking()
    
    // Fallback if network takes too long or adblocker blocks it
    this.timeout = setTimeout(() => this.hideLoader(), 10000)
  }

  disconnect() {
    this.cleanup()
  }

  injectScript() {
    // Inject the script if it doesn't exist
    if (!document.getElementById("tiktok-embed-script")) {
      const script = document.createElement("script")
      script.id = "tiktok-embed-script"
      script.src = "https://www.tiktok.com/embed.js"
      script.async = true
      document.body.appendChild(script)
    } else {
      // If script is already there, TikTok automatically runs on load.
      // For dynamic creations, we might need a little nudge.
      // Re-triggering the script by appending it again works around the lack of a published load method.
      const newScript = document.createElement("script")
      newScript.src = "https://www.tiktok.com/embed.js?t=" + new Date().getTime()
      newScript.async = true
      document.body.appendChild(newScript)
      
      setTimeout(() => newScript.remove(), 2000)
    }
  }

  startChecking() {
    this.checkInterval = setInterval(() => {
      const iframe = this.element.querySelector('iframe')
      if (iframe) {
        const rect = iframe.getBoundingClientRect()
        // Wait until it has actual rendering height to hide the loader
        if (rect.height > 50) {
          this.hideLoader()
        }
      }
    }, 100)
  }

  hideLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.style.display = "none"
    }
    this.cleanup()
  }

  cleanup() {
    if (this.checkInterval) clearInterval(this.checkInterval)
    if (this.timeout) clearTimeout(this.timeout)
  }
}

