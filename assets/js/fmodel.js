import { FmodelTree, ProjectTree, SchMetaForm, Project, Diff } from "./vendor/fbox.min.js"
import autosize from "autosize"

var projectStore = Project.createProjectStore()
var projectBaseStore

const buffer = function (func, wait, scope) {
  var timer = null;
  return function () {
    if (timer) clearTimeout(timer)
    var args = arguments
    timer = setTimeout(function () {
      timer = null
      func.apply(scope, args)
    }, wait)
  }
}

export const start = ({ channel }) => {
  customElements.define("project-store", class extends HTMLElement {
    connectedCallback() {
      this.addEventListener("remote-connected", this.handleRemoteConnected)
      this.addEventListener("tree-command", buffer(this.handleTreeCommand.bind(this), 5))
      this.addEventListener("tree-command", buffer(this.handleProjectRemote.bind(this), 1000))
      this.addEventListener("search-selected", buffer(this.handleSearchSelected.bind(this), 5), true)
      this.addEventListener("tree-command", buffer(this.handlePostTreeCommand.bind(this), 5))
      this.addEventListener("sch-update", this.handleSchUpdate)

    }
    disconnectedCallback() {
      this.removeEventListener("remote-connected", this.handleRemoteConnected)
      this.removeEventListener("tree-command", buffer(this.handleTreeCommand.bind(this), 5))
      this.removeEventListener("tree-command", buffer(this.handleProjectRemote.bind(this), 1000))
      this.removeEventListener("search-selected", buffer(this.handleSearchSelected.bind(this), 5), true)
      this.removeEventListener("tree-command", buffer(this.handlePostTreeCommand.bind(this), 5))
      this.removeEventListener("sch-update", this.handleSchUpdate)
    }
    handleRemoteConnected(e) {
      let project = e.detail.project
      this.changeUrlSSR(project)

      this._projectStore = Project.projectToStore(project, projectStore)
      ProjectTree({ store: projectStore, target: "[id='project']", select: `[${project.currentFileKey}]` })
      Project.changeFile(projectStore, project.currentFileKey, location.hash.replace("#", ""))

      projectBaseStore = JSON.parse(JSON.stringify(projectStore))
      this.pushChanged()
    }
    handleTreeCommand(e) {
      Project.controller(projectStore, e.detail.target, e.detail.command, this.runDiff)
      document.activeAriaTree = e.detail.target.closest("[role='tree']")
      autosize(document.querySelectorAll("[id='fsch'] textarea"))
    }
    handleProjectRemote(e) {
      if (!window.userToken && !window.isUnclaimed) return
      if (!Project.isDiffableCmd(e.detail.command.name)) return

      Object.defineProperty(projectStore, "_diffToRemote", { value: this.runDiff(), writable: true })
      Project.taggedDiff(projectStore, (diff) => {
        channel.push("push_project", diff)
          .receive("ok", (updated_project) => {
            // let file = e.detail.target.closest("[data-tag='file']")
            // let filename = file?.key

            projectBaseStore = JSON.parse(JSON.stringify(projectStore))
            // this.runDiff()

            // projectStore.render()
            // if (!filename) return
            // let fileStore = Project.getFileStore(projectStore, filename)
            // if (fileStore)
            //   fileStore.render && fileStore.render()
          })
          .receive("error", (reasons) => console.log("update project failed", reasons))
          .receive("noop", (a) => a)
          .receive("timeout", () => console.log("Networking issue..."))
      })
    }
    runDiff() {
      return Diff.diff(projectStore, projectBaseStore)
    }
    handleSchUpdate(e) {
      let { detail, target } = e
      let fileStore = Project.getFileStore(projectStore, e.detail.file)
      let updated_sch = Project.SchMeta.update({ store: fileStore, detail })

      if (!window.userToken) return
      if (updated_sch)
        channel.push("push_sch_meta", { $anchor: updated_sch.$anchor, metadata: updated_sch.metadata })
          .receive("ok", (updated_metadata) => {
          })
    }
    handlePostTreeCommand(e) {
      this.changeUrl()
      this.pushChanged()
    }
    handleSearchSelected(e) {
      let filename = e.detail.value.file
      let fmodelname = e.detail.value.fmodel

      ProjectTree({ store: projectStore, target: "[id='project']", select: `[${filename}]` })
      Project.changeFile(this._projectStore, filename, `[${fmodelname}]`)
      this.changeUrl()
    }
    pushChanged() {
      for (let commbobox of this.querySelectorAll("combo-box"))
        commbobox.dispatchEvent(new CustomEvent("data-push", { detail: { _models: Project.anchorsModels(this._projectStore) } }))
    }
    changeUrlSSR() {
      if (project.currentFileKey && project.currentFileKey != "")
        history.replaceState(null, "", `${window.project_path}/m/${project.currentFileKey}${location.hash}`)
    }
    changeUrl() {
      let file = document.querySelector("[id='project'] [role='tree']")?._walker.currentNode
      let fmodel = document.querySelector("[id='fmodel'] [role='tree']")?._walker.currentNode
      if (!file || !fmodel) return

      let fileIsFile = file.getAttribute("data-tag") == "file"
      let fmodelIsNotFile = fmodel.getAttribute("data-tag") != "file"

      switch (true) {
        case !!(fileIsFile && file.key) && !!(fmodelIsNotFile && fmodel.id):
          history.replaceState(null, "", `${window.project_path}/m/${file.key}#${fmodel.id}`)
          break
        case !!(fileIsFile && file.key):
          history.replaceState(null, "", `${window.project_path}/m/${file.key}`)
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
    keydown({ key, altKey, ctrlKey, metaKey, shiftKey }) {
      document.activeAriaTree.dispatchEvent(new KeyboardEvent("keydown", { key, altKey, ctrlKey, metaKey, shiftKey }))
    }
  })
}
