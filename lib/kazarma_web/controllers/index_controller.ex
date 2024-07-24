# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.IndexController do
  use KazarmaWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", title: nil)
  end
end
