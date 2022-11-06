# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Object do
  @moduledoc false

  use KazarmaWeb, :live_view

  @impl true
  def mount(%{"uuid" => uuid}, _session, socket) do
    with ap_id <-
           KazarmaWeb.Router.Helpers.activity_pub_url(socket, :object, uuid),
         %ActivityPub.Object{public: true, data: %{"actor" => actor_id, "type" => "Note"}} =
           object <-
           ActivityPub.Object.get_cached_by_ap_id(ap_id) || ActivityPub.Object.get_by_id(uuid),
         {:ok, actor} <- ActivityPub.Actor.get_or_fetch_by_ap_id(actor_id) do
      previous_objects = traverse_replies_to(object) |> Enum.reverse()

      page_title =
        "#{String.replace(object.data["content"], ~r/(?<=.{20})(.+)/s, "...")} – #{actor.data["name"]}"

      {
        :ok,
        socket
        |> assign(object: object)
        |> assign(previous_objects: previous_objects)
        |> assign(actor: actor)
        |> assign(page_title: page_title),
        temporary_assigns: []
      }
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"address" => address}}, socket) do
    case Kazarma.search_user(address) do
      {:ok, actor} ->
        actor_path = Routes.activity_pub_path(socket, :actor, actor.username)
        {:noreply, push_navigate(socket, to: actor_path)}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("User not found"))}
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
