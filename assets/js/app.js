// SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
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

const copyButtons = document.getElementsByClassName("btn-copy")

Array.from(copyButtons).forEach(function (button) {
  const textField = document.getElementById(button.dataset.copyId)

  button.addEventListener("click", function () {
    textField.select()
    document.execCommand("copy")
  })
})
