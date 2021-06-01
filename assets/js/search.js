import { Project } from "./vendor/fbox.min.js"
import autoComplete from "@tarekraafat/autocomplete.js"

const typeSearch = (selector, anchorsModels, opts = {}) => {
  let comboboxOpts = {
    placeHolder: opts.placeHolder || "Choose type ...",
    resultsList: {
      maxResults: 15
    },
    resultItem: {
      highlight: {
        render: true
      },
    },
    onSelection: function (feedback) {
      this.inputField.value = feedback.selection.value.fmodelname
    }
  }
  onNavigate(selector)

  let types = Project.allSchs
    .map(a => a().t).filter(a => a != "value")
    .reduce((acc, t) => Object.assign(acc, { [t]: { display: t } }), {})
  let data = Object.assign({}, types, anchorsModels)
  let anchors = Object.keys(data)
  let datalist = []

  for (let i = 0; i < anchors.length; i++)
    datalist.push(Object.assign({ anchor: anchors[i], fmodelname: data[anchors[i]].display }, data[anchors[i]]))

  return new autoComplete({ ...comboboxOpts, selector: selector, data: { src: datalist, key: ["fmodelname"] } })
}

const projectSearch = (selector, anchorsModels, opts = {}) => {
  let comboboxOpts = {
    placeHolder: opts.placeHolder || "Choose type ...",
    resultsList: {
      maxResults: 30
    },
    resultItem: {
      content: (item, element) => {
        // element.setAttribute("id", item.value.display)
      },
      highlight: {
        render: true
      },
    },
    onSelection: function (feedback) {
      this.inputField.value = feedback.selection.value.fmodelname
      this.inputField.dispatchEvent(new CustomEvent("search-selected", { detail: { selector, value: feedback.selection.value } }))
    }
  }
  onNavigate(selector)

  let data = anchorsModels
  let anchors = Object.keys(data)
  let datalist = []

  for (let i = 0; i < anchors.length; i++)
    datalist.push(Object.assign({ anchor: anchors[i], fmodelname: data[anchors[i]].display }, data[anchors[i]]))

  return new autoComplete({ ...comboboxOpts, selector: selector, data: { src: datalist, key: ["fmodelname"] } })
}

const onNavigate = (selector) => {
  document.querySelector(`${selector}`).addEventListener("navigate", function (event) {
    let list = document.querySelector(`[id='${this.getAttribute("aria-controls")}']`)
    let option = list.querySelector(`[id='${this.getAttribute("aria-activedescendant")}']`)
    // Equivalent to option.scrollIntoView(false)
    if (option.offsetTop + option.offsetHeight < list.offsetHeight)
      list.scrollTop = 0
    else
      list.scrollTop = option.offsetTop - (list.offsetHeight - option.offsetHeight);
  })
}

export const start = () => {
  customElements.define("combo-box", class extends HTMLElement {
    connectedCallback() {
      this.addEventListener("data-push", this.handleDataPush, true)
      this.dispatchEvent(new CustomEvent("data-request", { detail: { kind: this.getAttribute("list") } }))
    }
    handleDataPush(e) {
      e.stopPropagation()
      this.models = e.detail._models
      this.createAutoComplete()
    }
    createAutoComplete() {
      let input = this.querySelector("textarea, input")

      switch (this.getAttribute("list")) {
        case "typesearch":
          if (input.id) typeSearch(`#${input.id}`, this.models, { placeHolder: this.getAttribute("placeholder") })
          break
        case "jumptotype":
          if (input.id) projectSearch(`#${input.id}`, this.models, { placeHolder: this.getAttribute("placeholder") })
          break
      }
    }
    disconnectedCallback() {
      this.removeEventListener("data-request", this.handleLoadDatalist)
    }
  })
}

export default { start }
