# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ObjectController do
  use KazarmaWeb, :controller

  def show(conn, %{"uuid" => uuid}) do
    case ActivityPub.Object.get_by_id(uuid) do
      %{data: %{"type" => "Note"}} = object ->
        {:ok, actor} =
          object.data["actor"]
          |> ActivityPub.Actor.get_or_fetch_by_ap_id()

        previous_objects = traverse_replies_to(object) |> Enum.reverse()

        conn
        |> fetch_session()
        |> fetch_flash()
        |> protect_from_forgery()
        |> put_layout({KazarmaWeb.LayoutView, "app.html"})
        |> put_view(KazarmaWeb.ObjectView)
        |> render("show.html",
          object: object,
          previous_objects: previous_objects,
          actor: actor,
          title: KazarmaWeb.ObjectView.text_content(object) |> String.slice(0, 60)
        )

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

  defp traverse_replies_to(%{data: %{"inReplyTo" => reply_to_id}}) do
    case ActivityPub.Object.get_cached_by_ap_id(reply_to_id) do
      %{data: %{"type" => "Note"}} = reply_to ->
        [reply_to | traverse_replies_to(reply_to)]

      _ ->
        []
    end
  end

  defp traverse_replies_to(_), do: []
end
