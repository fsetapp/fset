import phoenix from "phoenix"
const { Socket } = phoenix

let socket = new Socket("/socket", { params: { token: window.userToken, projectname: window.projectName } })
let channel = socket.channel(`project:${window.projectName}`, { filename: window.currentFile })

if (window.userToken || window.projectName) {
  let socketNotOpened = true
  socket.onOpen(e => socketNotOpened = false)
  socket.onClose(e => {
    if (socketNotOpened) {
      socket.reconnectTimer.reset()
      window.location.replace("/status/404.html")
    }
  })
  socket.connect()
}

if (window.projectName) {
  console.time("join")
  channel.join()
    .receive("ok", resp => {
      console.timeEnd("join")
      document.querySelector("project-store")
        .dispatchEvent(new CustomEvent("remote-connected", { detail: { project: resp } }))
    })
    .receive("error", resp => { console.log("Unable to join", resp) })
}

export default socket
export { channel }
