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
  alias MatrixAppService.Event
  require Logger

  def debug(message, metadata \\ []) do
    Logger.debug(message, metadata)
  end

  def info(message, metadata \\ []) do
    Logger.info(message, metadata)
  end

  def error(message, metadata \\ []) do
    Logger.error(message, metadata)
  end

  def warn(message, metadata \\ []) do
    Logger.warn(message, metadata)
  end

  def matrix_input(%Event{} = object) do
    send_to_file_log(object |> Map.from_struct(), :event)
  end

  def matrix_output(%Event{} = object) do
    send_to_file_log(object |> Map.from_struct(), :event)
  end

  def ap_input(object) do
    send_to_file_log(object, :activity)
  end

  def ap_output(object) do
    send_to_file_log(object, :activity)
  end

  defp send_to_file_log(object, device) do
    object
    |> Jason.encode!()
    |> Jason.Formatter.pretty_print()
    |> Logger.debug(device: device)
  end
end
