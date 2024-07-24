# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

[
  plugins: [Phoenix.LiveView.HTMLFormatter],
  import_deps: [:ecto, :phoenix],
  inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
