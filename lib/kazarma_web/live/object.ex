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
      next_objects = Kazarma.ActivityPub.Activity.get_replies_for(object)

      page_title =
        "#{String.replace(object.data["content"], ~r/(?<=.{20})(.+)/s, "...")} – #{actor.data["name"]}"

      {
        :ok,
        socket
        |> assign(object: object)
        |> assign(previous_objects: previous_objects)
        |> assign(next_objects: next_objects)
        |> assign(actor: actor)
        |> assign(page_title: page_title),
        temporary_assigns: []
      }
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Not found"))
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"address" => address}}, socket) do
    case Kazarma.search_user(address) do
      {:ok, actor} ->
        actor_path = Routes.activity_pub_path(socket, :actor, actor.username)
        # dirty fix because LiveView does not re-enable the form when redirecting
        send(self(), {:redirect, actor_path})
        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("User not found"))}
    end
  end

  @impl true
  def handle_info({:redirect, to}, socket) do
    {:noreply, push_navigate(socket, to: to)}
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
