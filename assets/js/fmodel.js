import { ProjectTree, Project, Diff } from "./vendor/fbox.min.js"

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
    constructor() {
      super()
      this.on = this.addEventListener
      this.off = this.removeEventListener
    }
    connectedCallback() {
      this.on("remote-connected", this.handleRemoteConnected)
      this.on("tree-command", buffer(this.handleTreeCommand.bind(this), 5))
      this.on("tree-command", buffer(this.handleRemotePush.bind(this), 1000))
      this.on("search-selected", this.handleSearchSelected.bind(this), true)
      this.on("tree-command", buffer(this.handlePostTreeCommand.bind(this), 5))
      this.on("sch-update", this.handleSchUpdate)
    }
    disconnectedCallback() {
      this.off("remote-connected", this.handleRemoteConnected)
      this.off("tree-command", buffer(this.handleTreeCommand.bind(this), 5))
      this.off("tree-command", buffer(this.handleRemotePush.bind(this), 1000))
      this.off("search-selected", this.handleSearchSelected.bind(this), true)
      this.off("tree-command", buffer(this.handlePostTreeCommand.bind(this), 5))
      this.off("sch-update", this.handleSchUpdate)
      this.channelOff()
    }
    channelOff() {
      channel.off("each_batch")
      channel.off("each_batch_finished")
      channel.off("sch_metas_map")
    }
    handleRemoteConnected(e) {
      this.channelOff()
      let project = e.detail.project
      this._projectStore = Project.projectToStore(project, projectStore)

      channel.on("each_batch", ({ batch }) => {
        for (let file of batch)
          this._projectStore.fields.push(Project.fileToStore(file))
      })
      channel.on("each_batch_finished", nothing => {
        this.changeUrlSSR(project)

        ProjectTree({ store: projectStore, target: "[id='project']", select: `[${project.currentFileKey}]` })
        Project.changeFile(projectStore, project.currentFileKey, location.hash.replace("#", ""))

        projectBaseStore = JSON.parse(JSON.stringify(this._projectStore))
        Diff.buildBaseIndices(projectBaseStore)
        this.pushChanged()
      })
      channel.on("sch_metas_map", ({ schMetas }) => {
        Project.mergeSchMetas(this._projectStore, schMetas)
        Project.changeFile(this._projectStore, project.currentFileKey, location.hash.replace("#", ""))
      })
    }
    handleTreeCommand(e) {
      Project.controller(projectStore, e.detail.target, e.detail.command, this.runDiff)
      document.activeAriaTree = e.detail.target.closest("[role='tree']")
    }
    handleRemotePush(e) {
      if (!window.userToken && !window.isUnclaimed) return
      if (!Project.isDiffableCmd(e.detail.command.name)) return

      this.diffRender(e)
      Project.taggedDiff(projectStore, (diff) => {
        channel.push("push_project", diff, 30_000)
          .receive("ok", (updated_project) => {
            projectBaseStore = JSON.parse(JSON.stringify(projectStore))
            Diff.buildBaseIndices(projectBaseStore)
          })
          .receive("error", (reasons) => console.log("update project failed", reasons))
          .receive("noop", (a) => a)
          .receive("timeout", () => console.log("Networking issue..."))
      })
    }
    runDiff() {
      return Diff.diff(projectStore, projectBaseStore)
    }
    diffRender(e) {
      Object.defineProperty(this._projectStore, "_diffToRemote", { value: this.runDiff(), writable: true })
      let file = e.detail.target.closest("[data-tag='file']")
      let filename = file?.key
      let fileStore = Project.getFileStore(this._projectStore, filename)
      fileStore?.render()
    }
    handleSchUpdate(e) {
      let { detail, target } = e
      let fileStore = Project.getFileStore(projectStore, e.detail.file)
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

      Project.changeFile(this._projectStore, filename, `[${fmodelname}]`, true)
      ProjectTree({ store: projectStore, target: "[id='project']", select: `[${filename}]`, focus: false })
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
