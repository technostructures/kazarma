# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ObjectController do
  use KazarmaWeb, :controller

  def show(conn, %{"uuid" => uuid}) do
    # get_actor_function =
    #  if Application.get_env(:kazarma, :html_actor_view_include_remote, false) do
    #    :get_or_fetch_by_username
    #  else
    #    :get_cached_by_username
    #  end

    # case apply(ActivityPub.Actor, get_actor_function, [username]) do

    case KazarmaWeb.Router.Helpers.activity_pub_url(KazarmaWeb.Endpoint, :object, uuid)
         |> ActivityPub.Object.get_or_fetch_by_ap_id() do
      {:ok, object} ->
        {:ok, actor} =
          object.data["actor"]
          |> ActivityPub.Actor.get_or_fetch_by_ap_id()

        conn
        |> fetch_session()
        |> fetch_flash()
        |> protect_from_forgery()
        |> put_layout({KazarmaWeb.LayoutView, "app.html"})
        |> put_view(KazarmaWeb.ObjectView)
        # TODO: title
        |> render("show.html", object: object, actor: actor, title: "title")

      _ ->
        conn
        |> fetch_session()
        |> fetch_flash()
        |> protect_from_forgery()
        |> put_layout({KazarmaWeb.LayoutView, "app.html"})
        |> put_flash(:error, gettext("Object not found"))
        |> redirect(to: Routes.index_path(conn, :index))
    end
  end
end
