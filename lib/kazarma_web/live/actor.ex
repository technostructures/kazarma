# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Actor do
  @moduledoc false
  use KazarmaWeb, :live_view

  def get_actor(username) do
    include_remote = Application.get_env(:kazarma, :html_actor_view_include_remote, false)

    case ActivityPub.Actor.get_cached_or_fetch(username: username) do
      {:ok, %{local: true} = actor} -> {:ok, actor}
      {:ok, %{local: false} = actor} when include_remote == true -> {:ok, actor}
      _ -> nil
    end
  end

  @impl true
  def mount(%{"localpart" => localpart, "server" => "-"}, session, socket) do
    mount(%{"username" => "#{localpart}@#{Kazarma.Address.domain()}"}, session, socket)
  end

  def mount(%{"localpart" => localpart, "server" => server}, session, socket) do
    mount(%{"username" => "#{localpart}@#{server}"}, session, socket)
  end

  def mount(%{"username" => username}, session, socket) do
    put_session_locale(session)

    case get_actor(username) do
      {:ok, actor} ->
        public_activities = public_activities(actor)

        page_title = String.replace(actor.data["name"], ~r/(?<=.{20})(.+)/s, "...")

        {
          :ok,
          socket
          |> assign(conn: socket)
          |> assign(offset: 0)
          |> assign(actor: actor)
          |> assign(last_page: is_list(public_activities) && length(public_activities) < 10)
          |> assign(page_title: page_title),
          temporary_assigns: [activities: public_activities]
        }

      _ ->
        {:ok, socket |> put_flash(:error, gettext("User not found")) |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("load_more", _, %{assigns: assigns} = socket) do
    activities =
      Kazarma.ActivityPub.Actor.public_activites_for_actor(assigns.actor, assigns.offset + 10)

    {:noreply,
     socket
     |> assign(offset: assigns.offset + 10)
     |> assign(activities: activities)
     |> assign(last_page: length(activities) < 10)}
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

  defp public_activities(%ActivityPub.Actor{local: true, ap_id: ap_id} = actor) do
    case Kazarma.Bridge.get_room_by_remote_id(ap_id) do
      %MatrixAppService.Bridge.Room{data: %{"type" => "matrix_user"}} ->
        Kazarma.ActivityPub.Actor.public_activites_for_actor(actor)

      _ ->
        :unbridged_matrix
    end
  end

  defp public_activities(%ActivityPub.Actor{local: false, ap_id: ap_id} = actor) do
    case Kazarma.Bridge.get_room_by_remote_id(ap_id) do
      %MatrixAppService.Bridge.Room{data: %{"type" => "ap_user"}} ->
        Kazarma.ActivityPub.Actor.public_activites_for_actor(actor)

      _ ->
        :unbridged_ap
    end
  end
end
