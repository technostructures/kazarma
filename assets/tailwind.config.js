// SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
// SPDX-License-Identifier: AGPL-3.0-only

module.exports = {
  mode: "jit",
  purge: [
    "./js/**/*.js",
    "./js/**/*.ts",
    "../lib/**/*.ex",
    "../lib/**/*.leex",
    "../lib/**/*.heex",
    "../lib/**/*.eex",
    "../lib/**/*.sface",
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('daisyui')
  ],
}
