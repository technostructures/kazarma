# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.LiveOrJsonPlug do
  @moduledoc false

  @behaviour Plug

  @impl Plug
  def init(_), do: nil

  @impl Plug
  def call(conn, _action) do
    if Phoenix.Controller.get_format(conn) == "html" do
      conn
    else
      case Phoenix.Router.route_info(KazarmaWeb.Router, "GET", conn.request_path, conn.host) do
        %{plug: Phoenix.LiveView.Plug, phoenix_live_view: lv, path_params: _path_params} ->
          {_view, action, _opts, _live_session} = lv

          # we make an exception for Lemmy application actor
          {action, params} =
            if action == :index do
              {:actor,
               %{
                 "_format" => "activity+json",
                 "localpart" => Kazarma.Address.application_localpart(),
                 "server" => "-",
                 "username" => Kazarma.Address.application_username()
               }}
            else
              {action, conn.params}
            end

          apply(ActivityPub.Web.ActivityPubController, action, [conn, params])
          |> Plug.Conn.halt()
      end
    end
  end
end
