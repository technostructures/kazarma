// SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
// SPDX-License-Identifier: AGPL-3.0-only

// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"


// copy buttons in actor view

// const copyButtons = document.getElementsByClassName("btn-copy")
//
// Array.from(copyButtons).forEach(function (button) {
//   const textField = document.getElementById(button.dataset.copyId)
//
//   button.addEventListener("click", function () {
//     textField.select()
//     document.execCommand("copy")
//   })
// })

// copy buttons in profile component

const copyButtons = document.querySelectorAll('[data-copy]')

Array.from(copyButtons).forEach(function (button) {
  const text = button.dataset.copy

  button.addEventListener("click", function () {
    let tempInput = document.createElement("input")
    tempInput.value = text
    document.body.appendChild(tempInput)
    tempInput.select()
    
    document.execCommand("copy")
    document.body.removeChild(tempInput)
  })
})

import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
import topbar from "topbar"
topbar.config({barColors: {0: "#7e00f0"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// Connect if there are any LiveViews on the page
liveSocket.connect()

// Expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
// The latency simulator is enabled for the duration of the browser session.
// Call disableLatencySim() to disable:
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
