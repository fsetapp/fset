import { initModelView, initFileView, update, Project } from "./vendor/fbox.min.js"

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
      this.addEventListener("tree-command", this.handleTreeCommand)
      this.addEventListener("tree-command", buffer(this.handleProjectRemote, 1000))
      this.addEventListener("sch-update", this.handleSchUpdate)
    }
    disconnectedCallback() {
      this.removeEventListener("remote-connected", this.handleRemoteConnected)
      this.removeEventListener("tree-command", this.handleTreeCommand)
      this.removeEventListener("tree-command", buffer(this.handleProjectRemote, 1000))
      this.removeEventListener("sch-update", this.handleSchUpdate)
    }
    handleRemoteConnected(e) {
      let project = e.detail.project
      Project.projectToStore(project, projectStore)

      let currentFile = project.files.find(f => f.anchor == project.current_file) || projectStore.fields[project.order[0]]
      initFileView({ store: projectStore, target: "[id='project']" })

      let fileStore
      if (currentFile) {
        fileStore = Project.getFileStore(projectStore, currentFile.key)
        fileStore._models = Project.anchorsModels(projectStore, fileStore)
        initModelView({ store: fileStore, target: "[id='fmodel']", metaSelector: "sch-meta" })
      }
      projectBaseStore = JSON.parse(JSON.stringify(projectStore))
    }
    handleTreeCommand(e) {
      Project.handleProjectContext(projectStore, e.detail.target, e.detail.command)
      document.activeAriaTree = e.detail.target.closest("[role='tree']")
    }
    handleProjectRemote(e) {
      Project.handleProjectRemote(projectStore, projectBaseStore, e.detail.command, (diff) => {
        channel.push("push_project", diff)
          .receive("ok", (updated_project) => {
            // Project.projectToStore(updated_project, projectBaseStore)
            projectBaseStore = JSON.parse(JSON.stringify(projectStore))
            // console.log("updated porject", updated_project)
          })
          .receive("error", (reasons) => console.log("update project failed", reasons))
          .receive("timeout", () => console.log("Networking issue..."))
      })
    }
    handleSchUpdate(e) {
      let { detail, target } = e
      let fileStore = Project.getFileStore(projectStore, e.detail.file)

      // fileStore which does not have .render is a fresh fileStore without component initialization.
      // That means this handler being going on is stale. `handleSchUpdate` only work with fileStore
      // initialized with modelView component
      if (fileStore?.render) {
        let updated_sch = update({ store: fileStore, detail, target })

        if (updated_sch)
          channel.push("push_sch_meta", { $anchor: updated_sch.$anchor, metadata: updated_sch.metadata })
            .receive("ok", (updated_metadata) => {
            })
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
      switch (e.target.closest("[data-tree-action]").dataset.treeAction) {
        case "mark_as_main": this.keydown({ key: "m" }); break
        case "move_up": this.keydown({ key: "ArrowUp", altKey: true }); break
        case "move_down": this.keydown({ key: "ArrowDown", altKey: true }); break
        case "clone": this.keydown({ key: "ArrowDown", shiftKey: true, altKey: true }); break
        case "copy": this.keydown({ key: "c", metaKey: true }); break
        case "cut": this.keydown({ key: "x", metaKey: true }); break
        case "paste": this.keydown({ key: "v", metaKey: true }); break
        case "delete": this.keydown({ key: "Delete" }); break
      }
    }
    keydown({ key, altKey, ctrlKey, metaKey, shiftKey }) {
      document.activeAriaTree.dispatchEvent(new KeyboardEvent("keydown", { key, altKey, ctrlKey, metaKey, shiftKey }))
    }
  })
}
