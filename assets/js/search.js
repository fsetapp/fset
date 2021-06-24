import { Project, tstr } from "./vendor/fbox.min.js"
import autoComplete from "@tarekraafat/autocomplete.js"

const typeSearch = (selector, modelsGetter, opts = {}) => {
  let comboboxOpts = commonComboboxOpts({ maxResults: 15, placeHolder: opts.placeHolder })
  let types = Project.allSchs
    .map(a => a()).filter(sch => tstr(sch.t) != "value" || tstr(sch.t) != "ref")
    .reduce((acc, sch) => Object.assign(acc, { [tstr(sch.t)]: { display: tstr(sch.t), sch: sch, primitive: true } }), {})

  const modelsToDataList = (anchorsModels) => {
    let data = Object.assign({}, types, anchorsModels)
    let datalist = dataList(data, opts)
    return datalist
  }

  return new autoComplete({ ...comboboxOpts, selector: selector, data: { src: modelsGetter(modelsToDataList), keys: ["display"] } })
}

const projectSearch = (selector, modelsGetter, opts = {}) => {
  let comboboxOpts = commonComboboxOpts({
    maxResults: 30,
    placeHolder: opts.placeHolder,
    postSelection: (target, feedback) => {
      target.dispatchEvent(new CustomEvent("search-selected", { detail: { selector, value: feedback.selection.value } }))
    }
  })

  const modelsToDataList = (anchorsModels) => {
    let data = anchorsModels
    let datalist = dataList(data)
    return datalist
  }

  return new autoComplete({ ...comboboxOpts, selector: selector, data: { src: modelsGetter(modelsToDataList), keys: ["display"] } })
}

export const start = () => {
  customElements.define("combo-box", class extends HTMLElement {
    connectedCallback() {
      this._autocomplete = null
      this.addEventListener("data-push", this.handleDataPush, true)
    }
    handleDataPush(e) {
      e.stopPropagation()
      this.datalist = e.detail._models
      this.createAutoComplete()
    }
    createAutoComplete() {
      let input = this.querySelector("textarea, input")
      const dataList = f => async (query) => f(this.datalist)

      switch (this.getAttribute("list")) {
        case "typesearch":
          if (input.id) this._autocomplete ||= typeSearch(`#${input.id}`, dataList, { placeHolder: this.getAttribute("placeholder"), only: input.opts.allowedTs })
          break
        case "jumptotype":
          if (input.id) this._autocomplete ||= projectSearch(`#${input.id}`, dataList, { placeHolder: this.getAttribute("placeholder") })
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
      selected: "autoComplete_selected",
      element: (item, data) => {
        if (!data.value.primitive) {
          let t = document.createRange().createContextualFragment(`
            <span class="mx-1 text-gray-600">–</span>
            <span class="autoComplete_result_t">${tstr(data.value.sch.t)}</span>
          `)
          item.appendChild(t)
        }
      }
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

const dataList = (data, opts = {}) => {
  let anchors = Object.keys(data)
  let datalist = []

  for (let i = 0; i < anchors.length; i++) {
    let fmodel = data[anchors[i]]
    let fmodelname = fmodel.display
    fmodel.display = fmodel.display.replace(/</g, "&lt;")

    if (!opts.only)
      datalist.push(Object.assign({ anchor: anchors[i], fmodelname: fmodelname, }, fmodel))
    else
      if (opts.only.find(sch => {
        if (sch.to) return sch.to.t == fmodel.sch.t
        else return sch.t == fmodel.sch.t
      }))
        datalist.push(Object.assign({ anchor: anchors[i], fmodelname: fmodelname, }, fmodel))

  }

  return datalist
}

export default { start }
