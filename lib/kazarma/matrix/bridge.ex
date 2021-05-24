defmodule Kazarma.Matrix.Bridge do
  @moduledoc """
  Functions for the bridge database.
  """
  use MatrixAppService.BridgeConfig, repo: Kazarma.Repo

  def insert_chat_message_bridge_room(room_id, from_ap_id) do
    create_room(%{
      local_id: room_id,
      data: %{type: :chat_message, to_ap_id: from_ap_id}
    })
  end

  def insert_note_bridge_room(room_id, conversation, participants) do
    create_room(%{
      local_id: room_id,
      remote_id: conversation,
      data: %{type: :note, to: participants}
    })
  end

  def join_or_create_note_bridge_room(room_id, user_id) do
    room =
      case get_room_by_local_id(room_id) do
        nil ->
          {:ok, room} =
            create_room(%{
              local_id: room_id,
              remote_id: ActivityPub.Utils.generate_context_id(),
              data: %{"type" => "note", "to" => []}
            })

          room

        room ->
          room
      end

    updated_room_data = update_in(room.data["to"], &[user_id | &1]).data
    update_room(room, %{"data" => updated_room_data})
  end
end
