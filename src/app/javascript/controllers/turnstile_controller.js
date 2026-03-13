import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    sitekey: String,
    environment: String
  }
  static targets = ["widget", "submit"]

  connect() {
    if (this.environmentValue === "development") {
      this.enableSubmit()
      return
    }

    if (window.turnstile) {
      this.renderWidget()
    } else {
      document.addEventListener("turnstile:ready", () => {
        this.renderWidget()
      }, { once: true })

      this.loadScript()
    }

    this.disableSubmit()
  }

  renderWidget() {
    if (this.hasWidgetTarget) {
      turnstile.render(this.widgetTarget, {
        sitekey: this.sitekeyValue,
        callback: this.enableSubmit.bind(this),
        "error-callback": this.disableSubmit.bind(this),
        "expired-callback": this.disableSubmit.bind(this)
      })
    } else {
      console.warn("Turnstile widget target not found.")
    }
  }

  loadScript() {
    if (document.getElementById("turnstile-script")) return

    window.onloadTurnstileCallback = () => {
      document.dispatchEvent(new Event("turnstile:ready"))
    }

    const script = document.createElement("script")
    script.id = "turnstile-script"
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onloadTurnstileCallback&render=explicit"
    script.async = true
    script.defer = true
    document.head.appendChild(script)
  }

  disableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }

  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
  }
}
