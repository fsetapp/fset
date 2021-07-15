import { View } from "./vendor/fbox.min.js"

customElements.define("def-fmodel", class extends HTMLElement {
  connectedCallback() {
    console.log(JSON.parse(this.dataset.sch))
    View.rFmodelTree({ store: JSON.parse(this.dataset.sch), target: `[data-name=${this.dataset.name}]`, select: false })
    // this.setAttribute("data-sch", "")
  }
  disconnectedCallback() {

  }
})
