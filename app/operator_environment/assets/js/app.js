import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let Hooks = {}

Hooks.MacroInput = {
  mounted() {
    this.onKeydown = (event) => {
      if (event.key === "Enter" && event.shiftKey) {
        event.preventDefault()

        const severityInput = document.getElementById(this.el.dataset.severityTarget)
        const severity = severityInput ? severityInput.value : "0.5"

        this.pushEvent("bundle_input", {
          value: this.el.value,
          severity: severity
        })
      }
    }

    this.el.addEventListener("keydown", this.onKeydown)
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.onKeydown)
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

liveSocket.connect()
window.liveSocket = liveSocket
