import autoComplete from "@tarekraafat/autocomplete.js"

let comboboxOpts = {
  placeHolder: "Choose type ...",
  data: {
    src: []
  },
  resultItem: {
    highlight: {
      render: true
    },
  },
  onSelection: function (feedback) {
    this.inputField.value = feedback.selection.value
  }
}

export const start = () => {
  customElements.define("combo-box", class extends HTMLElement {
    connectedCallback() {
      let acc = ["string", "record", "list", "tuple", "boolean", "number", "union", "null", "any"]
      for (let anchor of Object.keys(this.models.list))
        acc.push(this.models.list[anchor])

      let anyInput = this.querySelector("textarea,input")
      if (anyInput?.id)
        this._combobox = new autoComplete({ ...comboboxOpts, selector: `#${anyInput.id}`, data: { src: acc } })
    }
    disconnectedCallback() {
      this._combobox = null
    }
  })
}

export default { start }
