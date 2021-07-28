import "phoenix_html"
import { View } from "./vendor/fbox.min.js"

window.addEventListener("hashchange", e => {
  for (let a of document.body.querySelectorAll(`[data-current]`)) a.removeAttribute("data-current")
  document.body.querySelector(`[href='${location.hash}']`)?.setAttribute("data-current", true)
})

customElements.define("def-fmodel", class extends HTMLElement {
  connectedCallback() {
    View.rFmodelTree({ store: JSON.parse(this.dataset.sch), target: `[data-name=${this.dataset.name}]`, select: false })
    this.setAttribute("data-sch", "")
  }
})
