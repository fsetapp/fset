import { init, update, store } from "./vendor/fbox.min.js"

export const start = ({ channel }) => {
  document.addEventListener("sch-update", (e) => {
    let { detail, target } = e
    update({ store: store, detail, target })
    channel.push("save_project", store)
  })

  addEventListener("DOMContentLoaded", e => {
    document.addEventListener("remote_connected", e => {
      let project = e.detail.project
      let current_file = project.files.find(f => f.id == project.current_file)

      current_file.fmodels.forEach(fmodel => {
        store.fields[fmodel.key] = fmodel.sch
        store.order.push(fmodel.key)
      })

      init({ store, treeSelector: "[id='fmodel'] [role='tree']", metaSelector: "sch-meta" })
    })
  })
}
