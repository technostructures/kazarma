require Protocol
Protocol.derive(Jason.Encoder, ActivityPub.Actor)
Protocol.derive(Jason.Encoder, ActivityPub.Object, only: [:id, :data, :local, :public, :inserted_at, :updated_at])

defmodule Kazarma.Logger do
  alias ActivityPub.Object
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

  def matrix_input(%Event{} = object) do
    send_to_file_log(object |> Map.from_struct) # TODO: Test without from_struct
  end

  def matrix_output(%Event{} = object) do
    send_to_file_log(object |> Map.from_struct)
  end

  def ap_input(object) do
    send_to_file_log(object)
  end

  def ap_output(object) do
    send_to_file_log(object)
  end

  defp send_to_file_log(object, device \\ 1) do
    object
    |> Jason.encode!
    |> Jason.Formatter.pretty_print
    |> Logger.debug(device: device)
  end
end
