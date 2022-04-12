import phoenix from "phoenix"
const { Socket } = phoenix

let channel, socket
if (window.projectName) {
  socket = new Socket("/socket", { params: { token: window.userToken, projectname: window.projectName } })
  channel = socket.channel(`project:${window.projectName}`, { filename: window.currentFile })

  let socketNotOpened = true
  socket.onOpen(e => socketNotOpened = false)
  socket.onClose(e => {
    if (socketNotOpened) {
      socket.reconnectTimer.reset()
      window.location.replace("/status/404.html")
    }
  })

  socket.connect()

  channel.join()
    .receive("ok", resp => {
      document.querySelector("project-store")
        .dispatchEvent(new CustomEvent("remote-connected", { detail: { project: resp } }))
    })
    .receive("error", resp => {
      switch (resp.reason) {
        case "expried":
          location.reload()
        default:
          console.log("Unable to join", resp)
      }
    })
}

export default socket
export { channel }
