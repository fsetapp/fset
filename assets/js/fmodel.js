import { initModelView, initFileView, update, Project } from "./vendor/fbox.min.js"

var projectStore = Project.createProjectStore()
var projectBaseStore

export const start = ({ channel }) => {
  customElements.define("sch-listener", class extends HTMLElement {
    connectedCallback() {
      this.addEventListener("remote-connected", this.handleRemoteConnected)
      this.addEventListener("tree-command", this.handleTreeCommand)
      this.addEventListener("sch-update", this.handleSchUpdate)
    }
    disconnectedCallback() {
      this.removeEventListener("remote-connected", this.handleRemoteConnected)
      this.removeEventListener("tree-command", this.handleTreeCommand)
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
      Project.handleProjectContext(projectStore, e.target, e.detail.file, e.detail.command)
      setTimeout(() => {
        Project.handleProjectRemote(projectStore, projectBaseStore, e.detail.command, (diff) => {
          if (!window.pushProject) return
          channel.push("push_project", diff)
            .receive("ok", (updated_project) => {
              // Project.projectToStore(updated_project, projectBaseStore)
              projectBaseStore = JSON.parse(JSON.stringify(projectStore))
              // console.log("updated porject", updated_project)
            })
            .receive("error", (reasons) => console.log("update project failed", reasons))
            .receive("timeout", () => console.log("Networking issue..."))
        })
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
}
