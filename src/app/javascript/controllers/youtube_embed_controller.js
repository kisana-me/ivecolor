import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loader", "iframe"]

  connect() {
    if (this.hasIframeTarget) {
      this.iframeTarget.addEventListener("load", () => this.hideLoader())
    }

    // フォールバック (10秒で強制解除)
    this.timeout = setTimeout(() => this.hideLoader(), 10000)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  hideLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.style.display = "none"
    }
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }
}
