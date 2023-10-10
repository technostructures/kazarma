# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.Chat do
  @moduledoc """
  Functions for ChatMessage activities, used by Pleroma for its chat system.
  """
  alias ActivityPub.Object
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Address
  alias Kazarma.Bridge

  def create_from_ap(
        %{
          data: %{
            "actor" => from_id,
            "to" => [to_id]
          },
          object: %Object{
            data:
              %{
                "content" => _body
              } = object_data
          }
        } = _activity
      ) do
    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from_id),
         {:ok, room_id} <-
           get_or_create_direct_room(from_id, to_id) do
      attachment = Map.get(object_data, "attachment")

      Activity.send_message_and_attachment(matrix_id, room_id, object_data, [attachment])
    end
  end

  def create_from_event(event, room) do
    {:ok, sender} = Address.matrix_id_to_actor(event.sender)

    {:ok, activity} =
      Activity.create_from_event(
        event,
        sender: sender,
        to: [room.data["to_ap_id"]],
        type: "ChatMessage"
      )

    Kazarma.Logger.log_bridged_activity(activity,
      room_type: :chat,
      room_id: room.local_id,
      obj_type: "Note"
    )
  end

  def handle_puppet_invite(user_id, sender_id, room_id) do
    case Kazarma.Address.matrix_id_to_actor(user_id) do
      {:ok, %ActivityPub.Actor{local: false}} ->
        Kazarma.Matrix.Client.join(user_id, room_id)
        create_bridge_room(user_id, room_id)
        Kazarma.Matrix.Client.put_new_direct_room_data(user_id, sender_id, room_id)

      _ ->
        :ok
    end
  end

  defp create_bridge_room(user_id, room_id) do
    with {:ok, actor} <- Kazarma.Address.matrix_id_to_actor(user_id, [:activity_pub]),
         {:ok, room} <- insert_bridge_room(room_id, actor.ap_id) do
      Kazarma.Logger.log_created_room(room,
        room_type: :chat,
        room_id: room_id
      )

      :ok
    else
      _ -> :error
    end
  end

  defp get_or_create_direct_room(from_ap_id, to_ap_id) do
    with {:ok, from_matrix_id} <- Address.ap_id_to_matrix(from_ap_id),
         {:ok, to_matrix_id} <- Address.ap_id_to_matrix(to_ap_id),
         {:error, :not_found} <-
           Kazarma.Matrix.Client.get_direct_room(from_matrix_id, to_matrix_id),
         {:ok, %{"room_id" => room_id}} <-
           Kazarma.Matrix.Client.create_direct_room(from_matrix_id, to_matrix_id),
         {:ok, room} <- insert_bridge_room(room_id, from_ap_id) do
      Kazarma.Logger.log_created_room(room,
        room_type: :chat,
        room_id: room_id
      )

      {:ok, room_id}
    else
      {:ok, room_id} -> {:ok, room_id}
      {:error, error} -> {:error, error}
    end
  end

  defp insert_bridge_room(room_id, from_ap_id) do
    Bridge.create_room(%{
      local_id: room_id,
      data: %{type: :chat, to_ap_id: from_ap_id}
    })
  end
end
