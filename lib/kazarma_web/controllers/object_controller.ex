# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ObjectController do
  use KazarmaWeb, :controller

  def show(conn, %{"uuid" => uuid}) do
    case ActivityPub.Object.get_by_id(uuid) do
      nil ->
        conn
        |> fetch_session()
        |> fetch_flash()
        |> protect_from_forgery()
        |> put_layout({KazarmaWeb.LayoutView, "app.html"})
        |> put_flash(:error, gettext("Object not found"))
        |> redirect(to: Routes.index_path(conn, :index))

      object ->
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
    end
  end
end
