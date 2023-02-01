// SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
// SPDX-License-Identifier: AGPL-3.0-only

const defaultTheme = require('tailwindcss/defaultTheme')

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
    extend: {
      fontFamily: {
          'sans': ['Roboto', ...defaultTheme.fontFamily.sans],
      }
    },
  },
  variants: {
    extend: {},
  },
  daisyui: {
    themes: [
      {
        mytheme: {
         "primary": "#650ef0",
         "secondary": "#ff2ef0",
         "accent": "#ffddd4",
         "neutral": "#4b5563",
         "base-100": "#FFFaf0",
         "info": "#650ef0",
         "success": "#42d684",
         "warning": "#ff7b52",
         "error": "#ff7b52",
        },
      },
    ],
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('daisyui')
  ],
}
