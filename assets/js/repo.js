import * as Model from "@fsetapp/fset/pkgs/model.js"
import * as Json from "@fsetapp/fset/pkgs/json.js"
import * as File from "@fsetapp/fset/pkgs/file.js"
import { Project } from "@fsetapp/fset"
import { buffer } from "./utils.js"
import ProjectURL from "./lib/project_url.js"

const { Store, Controller, Diff, Remote } = Project
var structSheet = {}

export const init = (name, channel) => {
  customElements.define(name || "project-store", class extends HTMLElement {
    constructor() {
      super()
      this.on = this.addEventListener
      this.off = this.removeEventListener
    }
    connectedCallback() {
      this.on("remote-connected", this.handleRemoteConnected)
      this.on("tree-command", buffer(this.handleTreeCommand.bind(this), 5))
      this.on("tree-command", this.handleRemotePush.bind(this))
      this.on("search-selected", this.handleSearchSelected.bind(this), true)
      this.on("tree-command", buffer(this.handlePostTreeCommand.bind(this), 5))
      this.on("sch-update", this.handleSchUpdate)
    }
    disconnectedCallback() {
      this.off("remote-connected", this.handleRemoteConnected.bind(this))
      this.off("tree-command", buffer(this.handleTreeCommand.bind(this), 5))
      this.off("tree-command", this.handleRemotePush.bind(this))
      this.off("search-selected", this.handleSearchSelected.bind(this), true)
      this.off("tree-command", buffer(this.handlePostTreeCommand.bind(this), 5))
      this.off("sch-update", this.handleSchUpdate)
      this.channelOff()
    }
    channelOff() {
      channel.off("each_batch")
      channel.off("each_batch_finished")
      channel.off("sch_metas_map")
      channel.off("referrers_map")
      channel.off("persisted_diff_result")
    }
    handleRemoteConnected(e) {
      this.channelOff()
      let project = e.detail.project

      this._store = Store.fromProject(project, { imports: [File, Model, Json] })
      this._store.url = { path: window.project_path }

      channel.on("persisted_diff_result", (saved_diffs) => {
        Diff.mergeToCurrent(this._store, saved_diffs)
        Diff.mergeToBase(this._base, saved_diffs)
        this.diffRender({ anchorsModelsUpdate: true })
        buffer(this.pushChanged.bind(this), 100)()
      })
      channel.on("each_batch", ({ batch }) => {
        for (let file of batch)
          this._store.fields.push(file)
      })
      channel.on("each_batch_finished", nothing => {
        const { url, currentFile } = this._store
        Store.buildFolderTree(this._store)

        ProjectURL.replaceWith({ url, currentFile })

        File.FileTree({ target: "[id='project']", fileBody: "file-body", select: decodeURIComponent(`[${currentFile?.key}]`) }, this._store)
        File.changeFile({ projectStore: this._store, tree: { _passthrough: { fileBody: "file-body" } }, filename: currentFile?.key, fmodelname: decodeURIComponent(location.hash.replace("#", "")) })

        this._base = JSON.parse(JSON.stringify(this._store))
        Store.Indice.buildBaseIndices(this._base)
        this.pushChanged()
      })
      channel.on("sch_metas_map", ({ schMetas, phase }) => {
        Store.Pull.mergeSchMetas(this._store, schMetas)
        this.rerenderCurrentFile(null, phase)
      })
      channel.on("referrers_map", ({ referrers, phase }) => {
        Store.Pull.mergeReferrers(this._store, referrers)
        this.rerenderCurrentFile(null, phase)
      })
    }
    handleTreeCommand(e) {
      Controller.router(this._store, e.detail)
      document.activeAriaTree = e.detail.target.closest("[role='tree']")
    }
    handleRemotePush(e) {
      if (!window.userToken && !window.isUnclaimed) return
      this.cmdQueue ||= []
      this.cmdQueue.push(e)

      this.push = buffer(() => {
        if (this.cmdQueue.find(cmd => Controller.isDiffableCmd(cmd.detail.command.name))) {
          this.pushToRemote(e)
          this.cmdQueue = []
        }
      }, 500)
      this.push()
    }
    pushToRemote(e) {
      this.diffRender()
      Remote.taggedDiff(this._store, (diff) => {
        channel.push("push_project", diff, 30_000)
          .receive("ok", (saved_diffs) => {
            console.log(saved_diffs)
            Diff.mergeToBase(this._base, saved_diffs)
            this.diffRender()
          })
          .receive("error", (reasons) => console.log("update project failed", reasons))
          .receive("noop", (a) => a)
          .receive("timeout", () => console.log("Networking issue..."))
      })
    }
    runDiff() {
      return Diff.diff(this._store, this._base)
    }
    diffRender(opts = {}) {
      Object.defineProperty(this._store, "_diffToRemote", { value: this.runDiff(), writable: true })
      this.rerenderCurrentFile(fileStore => {
        if (opts.anchorsModelsUpdate)
          fileStore._models = Store.Indice.anchorsModels(this._store)
      })
      this._store.render()
    }
    rerenderCurrentFile(f, phase) {
      f ||= a => a

      let fileStore = this._store._currentFileStore
      f(fileStore)
      fileStore?.render()
      // fileStore?.renderSchMeta()
    }
    handleSchUpdate(e) {
      let { detail, target } = e
      let fileStore = e.detail.file
      let updated_sch = Project.SchMeta.update({ store: fileStore, detail })

      if (!window.userToken) return
      if (updated_sch)
        channel.push("push_sch_meta", { $a: updated_sch.$a, metadata: updated_sch.metadata })
          .receive("ok", (updated_metadata) => {
          })
    }
    handlePostTreeCommand(e) {
      this.changeUrl()
      buffer(this.pushChanged.bind(this), 100)()
    }
    handleSearchSelected(e) {
      let filename = e.detail.value.file
      let fmodelname = e.detail.value.fmodel

      File.changeFile({ projectStore: this._store, tree: { _passthrough: { fileBody: "file-body" } }, filename, fmodelname: decodeURIComponent(`[${fmodelname}]`), focus: true })
      File.FileTree({ target: "[id='project']", fileBody: "file-body", select: decodeURIComponent(`[${filename}]`), focus: false }, this._store)
      this.changeUrl()
    }
    pushChanged() {
      for (let commbobox of this.querySelectorAll("combo-box"))
        commbobox.dispatchEvent(new CustomEvent("data-push", { detail: { _models: Store.Indice.anchorsModels(this._store) } }))
    }
    changeUrl() {
      let file = document.querySelector("[id='project'] [role='tree']")?._walker?.currentNode
      let fileBodyNode = document.querySelector("file-body [role='tree']")?._walker?.currentNode
      if (!file || !fileBodyNode) return

      let fileIsFile = file.getAttribute("data-tag") == "file"
      let notFileNode = fileBodyNode.getAttribute("data-tag") != "file"
      console.log(fileIsFile)
      console.log(file.key)
      this._store.currentFile = file
      switch (true) {
        case !!(fileIsFile && file.key) && !!(notFileNode && fileBodyNode.id):
          history.replaceState(null, "", `${window.project_path}/m/${encodeURIComponent(file.key)}#${fileBodyNode.id}`)
          break
        case !!(fileIsFile && file.key):
          history.replaceState(null, "", `${window.project_path}/m/${encodeURIComponent(file.key)}`)
          break
      }
    }
  })

  customElements.define("action-listener", class extends HTMLElement {
    connectedCallback() {
      this.addEventListener("click", this.handleAction)
    }
    disconnectedCallback() {
      this.removeEventListener("click", this.handleAction)
    }
    handleAction(e) {
      if (!document.activeAriaTree) return
      switch (e.target.closest("[data-tree-action]")?.dataset?.treeAction) {
        case "mark_as_main": this.keydown({ key: "m" }); break
        case "move_up": this.keydown({ key: "ArrowUp", altKey: true }); break
        case "move_down": this.keydown({ key: "ArrowDown", altKey: true }); break
        case "clone": this.keydown({ key: "ArrowDown", shiftKey: true, altKey: true }); break
        case "copy": this.keydown({ key: "c", metaKey: true }); break
        case "cut": this.keydown({ key: "x", metaKey: true }); break
        case "paste": this.keydown({ key: "v", metaKey: true }); break
        case "delete": this.keydown({ key: "Delete" }); break
        case "add_item": this.keydown({ key: "+", shiftKey: true }); break
      }
    }
    keydown({ key, altKey, ctrlKey, metaKey, shiftKey, detail = {} }) {
      let event = new KeyboardEvent("keydown", { key, altKey, ctrlKey, metaKey, shiftKey })
      event._detail = detail
      document.activeAriaTree.dispatchEvent(event)
    }
  })
}
