# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.HealthPlug do
  @moduledoc """
  Healthcheck plug.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/healthz"} = conn, _opts) do
    conn
    |> send_resp(200, "")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
