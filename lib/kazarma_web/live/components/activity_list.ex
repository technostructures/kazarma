# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.ActivityList do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.ActorView
  import KazarmaWeb.Gettext
  alias KazarmaWeb.Components.ActorLinks

  def show(assigns) do
    ~H"""
    <KazarmaWeb.Object.show :for={object <- @previous_objects} object={object} actor={actor_for_object(object)} conn={@conn} reply={true} />
    <KazarmaWeb.Object.show object={@object} actor={@actor} conn={@conn} reply={false} classes="" />
    """
  end

  defp actor_for_object(%{data: %{"actor" => actor_id}}) do
    case ActivityPub.Actor.get_cached_by_ap_id(actor_id) do
      {:ok, actor} -> actor
      _ -> nil
    end
  end

  defp actor_for_object(_), do: nil
end
