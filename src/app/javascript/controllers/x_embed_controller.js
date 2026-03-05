import { Controller } from "@hotwired/stimulus"

let twitterApiPromise

function loadTwitterWidgets() {
  if (twitterApiPromise) return twitterApiPromise

  twitterApiPromise = new Promise((resolve) => {
    if (window.twttr && typeof window.twttr.widgets.load === "function") {
      resolve(window.twttr)
      return
    }

    const script = document.createElement("script")
    script.src = "https://platform.twitter.com/widgets.js"
    script.async = true
    script.charset = "utf-8"
    script.onload = () => resolve(window.twttr)
    script.onerror = () => resolve(null)
    document.head.appendChild(script)
  })

  return twitterApiPromise
}

export default class extends Controller {
  static targets = ["loader"]

  connect() {
    loadTwitterWidgets().then((twttr) => {
      if (twttr && typeof twttr.widgets.load === "function") {
        twttr.widgets.load(this.element)
      }
    })

    // 監視対象：iframeが追加され、かつそのiframeの高さが10pxより大きくなった時（中身がレンダリングされた時）
    this.checkInterval = setInterval(() => {
      const iframe = this.element.querySelector('iframe')
      if (iframe) {
        // Twitterのiframeは初期ロード時に一時的にheight: 0や小さい値になる場合があるため、
        // 実際のコンテンツの高さが確保されたら準備完了とみなす
        const rect = iframe.getBoundingClientRect()
        if (rect.height > 50) {
          this.hideLoader()
        }
      }
    }, 100)

    // スクリプトの読み込みブロック等に備えてのフォールバック (10秒で強制解除)
    this.timeout = setTimeout(() => this.hideLoader(), 10000)
  }

  disconnect() {
    this.cleanup()
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
