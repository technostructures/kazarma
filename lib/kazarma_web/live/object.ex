# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Object do
  @moduledoc false

  use KazarmaWeb, :live_view
  alias KazarmaWeb.Router.Helpers, as: Routes

  @impl true
  def mount(%{"uuid" => uuid} = params, _session, socket) do
    {:ok, _raw_uuid} = Ecto.UUID.dump(uuid)

    %ActivityPub.Object{data: %{"actor" => actor_id}} =
      object = ActivityPub.Object.get_by_id(uuid)

    {:ok, actor} = ActivityPub.Actor.get_or_fetch_by_ap_id(actor_id)

    actor_room = Kazarma.Bridge.get_room_by_remote_id(actor_id)

    {:ok, maybe_load_object(object, actor, actor_room, socket)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"address" => address}}, socket) do
    case Kazarma.search_user(address) do
      {:ok, actor} ->
        actor_path = Kazarma.ActivityPub.Adapter.actor_path(actor)
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

  defp maybe_load_object(
         %ActivityPub.Object{
           public: true,
           local: local,
           data: %{"type" => "Note"}
         } = object,
         actor,
         room,
         socket
       ) do
    if local || room || connected?(socket) do
      load_object(object, actor, socket)
    else
      redirect_to_remote(object, socket)
    end
  end

  defp maybe_load_object(object, _actor, _room, socket) do
    redirect_to_remote(object, socket)
  end

  defp redirect_to_remote(%ActivityPub.Object{data: %{"id" => ap_id}}, socket) do
    redirect(socket, external: ap_id)
  end

  defp load_object(object, actor, socket) do
    previous_objects = traverse_replies_to(object) |> Enum.reverse()

    next_objects = Kazarma.ActivityPub.Activity.get_replies_for(object)

    stripped_content =
      object.data["content"]
      |> HtmlSanitizeEx.strip_tags()

    page_title =
      "#{String.replace(stripped_content, ~r/(?<=.{20})(.+)/s, "...")} – #{actor.data["name"]}"

    socket
    |> assign(object: object)
    |> assign(previous_objects: previous_objects)
    |> assign(next_objects: next_objects)
    |> assign(actor: actor)
    |> assign(page_title: page_title)
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
