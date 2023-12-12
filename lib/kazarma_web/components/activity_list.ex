# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.ActivityList do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML

  def show(assigns) do
    ~H"""
    <KazarmaWeb.Components.Object.show
      :for={object <- @previous_objects}
      :if={actor_for_object(object)}
      object={object}
      actor={actor_for_object(object)}
      type={:replied_to}
      socket={@socket}
    />
    <KazarmaWeb.Components.Object.show
      object={@object}
      actor={@actor}
      type={:main}
      socket={@socket}
      classes=""
    />
    <KazarmaWeb.Components.Object.show
      :for={object <- @next_objects}
      :if={actor_for_object(object)}
      object={object}
      actor={actor_for_object(object)}
      type={:reply}
      socket={@socket}
    />
    """
  end

  defp actor_for_object(%{data: %{"actor" => actor_id}}) do
    case ActivityPub.Actor.get_cached(ap_id: actor_id) do
      {:ok, actor} -> actor
      _ -> nil
    end
  end

  defp actor_for_object(_), do: nil
end
