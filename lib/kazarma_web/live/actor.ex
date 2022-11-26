# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Actor do
  @moduledoc false
  use KazarmaWeb, :live_view

  def get_actor(username) do
    if Application.get_env(:kazarma, :html_actor_view_include_remote, false) do
      ActivityPub.Actor.get_or_fetch_by_username(username)
    else
      ActivityPub.Actor.get_cached_by_username(username)
    end
  end

  @impl true
  def mount(%{"localpart" => localpart, "server" => "-"} = params, session, socket) do
    mount(%{"username" => "#{localpart}@#{Kazarma.Address.domain()}"}, session, socket)
  end

  def mount(%{"localpart" => localpart, "server" => server} = params, session, socket) do
    mount(%{"username" => "#{localpart}@#{server}"}, session, socket)
  end

  def mount(%{"username" => username}, _session, socket) do
    {:ok, actor} = get_actor(username)
    public_activities = Kazarma.ActivityPub.Actor.public_activites_for_actor(actor)
    page_title = String.replace(actor.data["name"], ~r/(?<=.{20})(.+)/s, "...")

    {
      :ok,
      socket
      |> assign(conn: socket)
      |> assign(offset: 0)
      |> assign(actor: actor)
      |> assign(last_page: length(public_activities) < 10)
      |> assign(page_title: page_title),
      temporary_assigns: [activities: public_activities]
    }
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
end
