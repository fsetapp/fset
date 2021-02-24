import { init, update, store } from "./vendor/fbox.min.js"

export const start = () => {
  document.addEventListener("sch-update", (e) => {
    let { detail, target } = e
    update({ store: store, detail, target })
  })

  addEventListener("DOMContentLoaded", e => {
    init({ store, treeSelector: "[id='fmodel'] [role='tree']", metaSelector: "sch-meta" })
  })
}
