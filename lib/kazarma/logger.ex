# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

require Protocol

Protocol.derive(Jason.Encoder, ActivityPub.Actor)

Protocol.derive(Jason.Encoder, ActivityPub.Object,
  only: [:id, :data, :local, :public, :inserted_at, :updated_at]
)

Protocol.derive(Jason.Encoder, MatrixAppService.Event)

defmodule Kazarma.Logger do
  @moduledoc """
  Kazarma logger
  """
  require Logger

  def log_received_activity(
        activity,
        opts \\ []
      ) do
    type = activity_type(activity) || Keyword.get(opts, :type)
    obj_type = activity_obj_type(activity) || Keyword.get(opts, :obj_type)

    :telemetry.execute([:kazarma, :activities, :received], %{}, %{
      type: type,
      obj_type: obj_type
    })

    "Received #{display_activity_type(type, obj_type)} activity"
    |> add_label(Keyword.get(opts, :label))
    |> Logger.info()

    inspect(activity, pretty: true)
    |> Logger.debug()
  end

  def log_bridged_activity(
        activity,
        opts \\ []
      ) do
    type = activity_type(activity) || Keyword.get(opts, :type)
    obj_type = activity_obj_type(activity) || Keyword.get(opts, :obj_type)
    room_type = Keyword.get(opts, :room_type)
    room_id = Keyword.get(opts, :room_id)

    :telemetry.execute([:kazarma, :activities, :bridged], %{}, %{
      type: type,
      obj_type: obj_type,
      room_type: room_type,
      room_id: room_id
    })

    Logger.info("Sent #{display_activity_type(type, obj_type)} activity")

    Logger.info("from #{room_type} room #{room_id}")

    inspect(activity, pretty: true)
    |> Logger.debug()
  end

  def log_received_event(
        %{type: type, room_id: room_id} = event,
        opts \\ []
      ) do
    type = Keyword.get(opts, :type) || type

    :telemetry.execute([:kazarma, :events, :received], %{}, %{
      type: type,
      room_id: room_id
    })

    "Received #{type} event"
    |> add_label(Keyword.get(opts, :label))
    |> Logger.info()

    inspect(event, pretty: true)
    |> Logger.debug()
  end

  def log_bridged_event(
        %{type: type, room_id: room_id} = event,
        opts \\ []
      ) do
    type = Keyword.get(opts, :type) || type
    room_type = Keyword.get(opts, :room_type)

    :telemetry.execute([:kazarma, :events, :bridged], %{}, %{
      type: type,
      room_type: room_type,
      room_id: room_id
    })

    Logger.notice("Sent #{type} event")

    Logger.info("to #{room_type} room #{room_id}")

    inspect(event, pretty: true)
    |> Logger.debug()
  end

  def log_created_room(
        room,
        opts \\ []
      ) do
    room_type = Keyword.get(opts, :room_type)
    room_id = Keyword.get(opts, :room_id)

    :telemetry.execute([:kazarma, :rooms, :created], %{}, %{
      room_type: room_type,
      room_id: room_id
    })

    Logger.notice("Created #{room_type} room")

    Logger.info("room ID: #{room_id}")

    inspect(room, pretty: true)
    |> Logger.debug()
  end

  def log_created_puppet(
        user,
        opts \\ []
      ) do
    type = Keyword.get(opts, :type)

    :telemetry.execute([:kazarma, :puppets, :created], %{}, %{
      type: type
    })

    Logger.notice("Created #{type} puppet")

    inspect(user, pretty: true)
    |> Logger.debug()
  end

  def derive_level(level, _message, {_date, _time}, _metadata) do
    [{"level", Atom.to_string(level)}]
  end

  defp activity_type(%{data: %{"type" => type}}) when is_binary(type), do: type
  defp activity_type(_), do: nil

  defp activity_obj_type(%{data: %{"object" => %{"type" => obj_type}}}) when is_binary(obj_type),
    do: obj_type

  defp activity_obj_type(_), do: nil

  defp display_activity_type(type, nil), do: type
  defp display_activity_type(type, obj_type), do: "#{type}/#{obj_type}"

  defp add_label(message, nil), do: message
  defp add_label(message, label), do: "#{message} (#{label})"
end
