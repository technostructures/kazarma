# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Timeline do
  @moduledoc false
  use KazarmaWeb, :live_view

  @impl true
  def mount(_params, %{"actor_id" => actor_id}, socket) do
    with {:ok, actor} <- ActivityPub.Actor.get_cached_by_ap_id(actor_id) do
      public_activities = Kazarma.ActivityPub.Actor.public_activites_for_actor(actor)

      {
        :ok,
        socket
        |> assign(conn: socket)
        |> assign(offset: 0)
        |> assign(actor: actor)
        |> assign(last_page: length(public_activities) < 10),
        temporary_assigns: [activities: public_activities]
      }
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
end
