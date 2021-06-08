import { Project, tstr } from "./vendor/fbox.min.js"
import autoComplete from "@tarekraafat/autocomplete.js"

const typeSearch = (selector, anchorsModels, opts = {}) => {
  let comboboxOpts = commonComboboxOpts({ maxResults: 15, placeHolder: opts.placeHolder })
  let types = Project.allSchs
    .map(a => tstr(a().t)).filter(t => t != "value")
    .reduce((acc, t) => Object.assign(acc, { [t]: { display: t } }), {})

  let data = Object.assign({}, types, anchorsModels)
  let datalist = dataList(data)

  return new autoComplete({ ...comboboxOpts, selector: selector, data: { src: datalist, keys: ["display"] } })
}

const projectSearch = (selector, anchorsModels, opts = {}) => {
  let comboboxOpts = commonComboboxOpts({
    maxResults: 30,
    placeHolder: opts.placeHolder,
    postSelection: (target, feedback) => {
      target.dispatchEvent(new CustomEvent("search-selected", { detail: { selector, value: feedback.selection.value } }))
    }
  })

  let data = anchorsModels
  let datalist = dataList(data)

  return new autoComplete({ ...comboboxOpts, selector: selector, data: { src: datalist, keys: ["display"] } })
}

export const start = () => {
  customElements.define("combo-box", class extends HTMLElement {
    connectedCallback() {
      this._autocomplete = null
      this.addEventListener("data-push", this.handleDataPush, true)
    }
    handleDataPush(e) {
      e.stopPropagation()
      this.models = e.detail._models
      this.createAutoComplete()
    }
    createAutoComplete() {
      this._autocomplete?.unInit()
      let input = this.querySelector("textarea, input")

      switch (this.getAttribute("list")) {
        case "typesearch":
          if (input.id) this._autocomplete = typeSearch(`#${input.id}`, this.models, { placeHolder: this.getAttribute("placeholder") })
          break
        case "jumptotype":
          if (input.id) this._autocomplete = projectSearch(`#${input.id}`, this.models, { placeHolder: this.getAttribute("placeholder") })
          break
      }
    }
    disconnectedCallback() {
      this.removeEventListener("data-push", this.handleDataPush, true)
      this._autocomplete?.unInit()
      this._autocomplete = null
    }
  })
}

const commonComboboxOpts = ({ maxResults, placeHolder, postSelection }) => {
  return {
    placeHolder: placeHolder || "Search ...",
    resultsList: {
      maxResults: maxResults || 30,
      class: "autoComplete_list"
    },
    resultItem: {
      class: "autoComplete_result",
      highlight: "autoComplete_highlighted",
      selected: "autoComplete_selected"
    },
    wrapper: false,
    query: input => input.replace(/</g, "&lt;"),
    events: {
      input: {
        selection: function (e) {
          const feedback = e.detail

          e.target.value = feedback.selection.value.fmodelname
          postSelection && postSelection(e.target, feedback)
        },
        navigate: function (e) {
          let list = document.querySelector(`[id='${this.getAttribute("aria-controls")}']`)
          let option = list.querySelector(`[id='${this.getAttribute("aria-activedescendant")}']`)
          // Equivalent to option.scrollIntoView(false)
          if (option.offsetTop + option.offsetHeight < list.offsetHeight)
            list.scrollTop = 0
          else
            list.scrollTop = option.offsetTop - (list.offsetHeight - option.offsetHeight);
        }
      }
    }
  }
}

const dataList = (data) => {
  let anchors = Object.keys(data)
  let datalist = []

  for (let i = 0; i < anchors.length; i++) {
    let fmodelname = data[anchors[i]].display
    data[anchors[i]].display = data[anchors[i]].display.replace(/</g, "&lt;")
    datalist.push(Object.assign({ anchor: anchors[i], fmodelname: fmodelname, }, data[anchors[i]]))
  }
  return datalist
}

export default { start }
