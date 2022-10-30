# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ActorController do
  use KazarmaWeb, :controller

  def get_actor(username) do
    if Application.get_env(:kazarma, :html_actor_view_include_remote, false) do
      ActivityPub.Actor.get_or_fetch_by_username(username)
    else
      ActivityPub.Actor.get_cached_by_username(username)
    end
  end

  def show(conn, %{"username" => username}) do
    with {:ok, actor} <- get_actor(username),
         objects <- [] do
      conn
      |> fetch_session()
      |> fetch_flash()
      |> protect_from_forgery()
      |> put_layout({KazarmaWeb.LayoutView, "app.html"})
      |> put_view(KazarmaWeb.ActorView)
      |> render("show.html", actor: actor, objects: objects, title: actor.data["name"])
    else
      {error, _} ->
        conn
        |> fetch_session()
        |> fetch_flash()
        |> protect_from_forgery()
        |> put_layout({KazarmaWeb.LayoutView, "app.html"})
        |> put_flash(:error, gettext("User not found"))
        |> redirect(to: Routes.index_path(conn, :index))
    end
  end
end
