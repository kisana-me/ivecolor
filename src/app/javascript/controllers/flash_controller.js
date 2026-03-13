import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar"]

  connect() {
    this.timeout = setTimeout(() => this.close(), 3000)
  }

  close() {
    clearTimeout(this.timeout)
    this.element.remove()
  }
}
