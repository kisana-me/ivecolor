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
      window.onloadTurnstileCallback = this.renderWidget.bind(this)
      this.loadScript()
    }
    this.disableSubmit()
  }

  renderWidget() {
    if(this.hasWidgetTarget) {
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
    const script = document.createElement("script")
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onloadTurnstileCallback"
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
