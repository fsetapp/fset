import "phoenix_html"
import { ReadOnlyFmodelTree } from "@fsetapp/fset/pkgs/model.js"

window.addEventListener("hashchange", e => {
  for (let a of document.body.querySelectorAll(`[data-current]`)) a.removeAttribute("data-current")
  document.body.querySelector(`[href='${location.hash}']`)?.setAttribute("data-current", true)
})

customElements.define("def-fmodel", class extends HTMLElement {
  connectedCallback() {
    ReadOnlyFmodelTree({ target: `[data-name=${this.dataset.name}]`, select: false }, JSON.parse(this.dataset.sch))
    this.setAttribute("data-sch", "")
  }
})
