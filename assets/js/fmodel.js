import { FmodelTree, ProjectTree, SchMetaForm, Project, Diff } from "./vendor/fbox.min.js"

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
  customElements.define("sch-listener", class extends HTMLElement {
    connectedCallback() {
      this.addEventListener("remote-connected", this.handleRemoteConnected)
      this.addEventListener("tree-command", buffer(this.handleTreeCommand.bind(this)))
      this.addEventListener("tree-command", buffer(this.handleProjectRemote.bind(this), 250))
      this.addEventListener("sch-update", this.handleSchUpdate)
    }
    disconnectedCallback() {
      this.removeEventListener("remote-connected", this.handleRemoteConnected)
      this.removeEventListener("tree-command", buffer(this.handleTreeCommand.bind(this)))
      this.removeEventListener("tree-command", buffer(this.handleProjectRemote.bind(this), 250))
      this.removeEventListener("sch-update", this.handleSchUpdate)
    }
    handleRemoteConnected(e) {
      let project = e.detail.project
      Project.projectToStore(project, projectStore)
      ProjectTree({ store: projectStore, target: "[id='project']" })

      let fileStore = Project.getFileStore(projectStore, project.currentFileKey)
      if (fileStore) {
        fileStore._models = Project.anchorsModels(projectStore, fileStore)
        FmodelTree({ store: fileStore, target: "[id='fmodel']", metaSelector: "sch-meta" })
        SchMetaForm({ store: fileStore, target: "[id='fsch']", treeTarget: "[id='fmodel']" })
      }
      projectBaseStore = JSON.parse(JSON.stringify(projectStore))
    }
    handleTreeCommand(e) {
      Project.controller(projectStore, e.detail.target, e.detail.command, this.runDiff)
      document.activeAriaTree = e.detail.target.closest("[role='tree']")
    }
    handleProjectRemote(e) {
      if (!window.userToken) return
      if (!Project.isDiffableCmd(e.detail.command.name)) return

      projectStore._diffToRemote = this.runDiff()
      Project.taggedDiff(projectStore, (diff) => {
        channel.push("push_project", diff)
          .receive("ok", (updated_project) => {
            let file = e.detail.target.closest("[data-tag='file']")
            let filename = file?.key

            // Project.projectToStore(updated_project, projectBaseStore)
            // projectBaseStore = JSON.parse(JSON.stringify(projectStore))
            this.runDiff()

            projectStore.render()
            if (filename) {
              let fileStore = Project.getFileStore(projectStore, filename)
              fileStore.render && fileStore.render()
            }
            // console.log("updated porject", updated_project)
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
