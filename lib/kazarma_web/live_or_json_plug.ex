# SPDX-FileCopyrightText: 2020-2024 Technostructures
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

          {action, params} = get_action_and_params(action, conn)

          apply(ActivityPub.Web.ActivityPubController, action, [conn, params])
          |> Plug.Conn.halt()
      end
    end
  end

  # we make an exception for Lemmy application actor
  defp get_action_and_params(:index, _) do
    {:actor,
     %{
       "_format" => "activity+json",
       "localpart" => Kazarma.Address.application_localpart(),
       "server" => "-",
       "username" => Kazarma.Address.application_username()
     }}
  end

  defp get_action_and_params(action, %{params: params}), do: {action, params}
end
