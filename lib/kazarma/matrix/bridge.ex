defmodule Kazarma.Matrix.Bridge do
  @moduledoc """
  Functions for the bridge database.
  """
  use MatrixAppService.BridgeConfig, repo: Kazarma.Repo

  def insert_chat_message_bridge_room(room_id, from_ap_id) do
    Kazarma.Matrix.Bridge.create_room(%{
      local_id: room_id,
      data: %{type: :chat_message, to_ap: from_ap_id}
    })
  end

  def insert_note_bridge_room(room_id, conversation, participants) do
    Kazarma.Matrix.Bridge.create_room(%{
      local_id: room_id,
      remote_id: conversation,
      data: %{type: :note, to: participants}
    })
  end
end
