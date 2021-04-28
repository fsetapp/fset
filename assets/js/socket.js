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
      window.location.replace("404.html")
    }
  })
  socket.connect()
}

if (window.projectName) {
  channel.join()
    .receive("ok", resp => {
      document.querySelector("sch-listener")
        .dispatchEvent(new CustomEvent("remote-connected", { detail: { project: resp } }))
    })
    .receive("error", resp => { console.log("Unable to join", resp) })
}

export default socket
export { channel }
