# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Kazarma.Telemetry do
  @moduledoc false

  def log_bridged_activity(
        %{data: data},
        opts
      ) do
    :telemetry.execute([:kazarma, :activities, :bridged], %{}, %{
      type: Keyword.get(opts, :type) || data["type"],
      obj_type: Keyword.get(opts, :obj_type) || data["object"]["type"],
      room_type: Keyword.get(opts, :room_type),
      room_id: Keyword.get(opts, :room_id)
    })
  end

  def log_bridged_event(
        %{type: type},
        opts
      ) do
    :telemetry.execute([:kazarma, :events, :bridged], %{}, %{
      type: Keyword.get(opts, :type) || type,
      room_type: Keyword.get(opts, :room_type),
      room_id: Keyword.get(opts, :room_id)
    })
  end

  def log_created_room(
        _room,
        opts
      ) do
    :telemetry.execute([:kazarma, :rooms, :created], %{}, %{
      room_type: Keyword.get(opts, :room_type),
      room_id: Keyword.get(opts, :room_id)
    })
  end
end
