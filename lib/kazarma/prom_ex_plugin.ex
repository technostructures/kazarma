# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.PromExPlugin do
  @moduledoc false
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :kazarma_bridge_event_metrics,
      [
        counter([:kazarma, :activities, :bridged, :total],
          event_name: [:kazarma, :activities, :bridged],
          tags: [:type, :obj_type, :room_type]
        ),
        counter([:kazarma, :events, :bridged, :total],
          event_name: [:kazarma, :events, :bridged],
          tags: [:type, :room_type]
        ),
        counter([:kazarma, :rooms, :created, :total],
          event_name: [:kazarma, :rooms, :created],
          tags: [:room_type]
        ),
        counter([:kazarma, :puppets, :created, :total],
          event_name: [:kazarma, :puppets, :created],
          tags: [:type]
        )
      ]
    )
  end
end
