import { initModelView, initFileView, update, Project } from "./vendor/fbox.min.js"

var projectStore = Project.createProjectStore()

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
      initFileView({ store: projectStore, target: "[id='project']" })

      let fileStore
      let current_file = project.files.find(f => f.id == project.current_file)
      if (current_file) {
        fileStore = Project.getFileStore(projectStore, current_file.key)
        fileStore._models = Project.anchorsModels(projectStore, fileStore)
        initModelView({ store: fileStore, target: "[id='fmodel']", metaSelector: "sch-meta" })
      }
    }
    handleTreeCommand(e) {
      Project.handleProjectContext(projectStore, e.target, e.detail.file, e.detail.command)
    }
    handleSchUpdate(e) {
      let { detail, target } = e
      let fileStore = Project.getFileStore(projectStore, e.detail.file)
      if (fileStore)
        update({ store: fileStore, detail, target })

      channel.push("save_project", fileStore)
    }
  })
}
