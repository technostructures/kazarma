# SPDX-FileCopyrightText: 2020-2024 Technostructures
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
    with %{local_id: matrix_id} <- Kazarma.Address.get_user(ap_id: from_id),
         {:ok, room_id} <-
           get_or_create_direct_room(from_id, to_id) do
      attachment = Map.get(object_data, "attachment")

      Activity.send_message_and_attachment(matrix_id, room_id, object_data, [attachment])
    end
  end

  def create_from_event(event, room) do
    %{} = sender = Address.get_actor(matrix_id: event.sender)

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
    case Kazarma.Address.get_actor(matrix_id: user_id) do
      %ActivityPub.Actor{local: false} ->
        Kazarma.Matrix.Client.join(user_id, room_id)
        create_bridge_room(user_id, room_id)
        Kazarma.Matrix.Client.put_new_direct_room_data(user_id, sender_id, room_id)

      _ ->
        :ok
    end
  end

  defp create_bridge_room(user_id, room_id) do
    with %{} = actor <- Kazarma.Address.get_actor(matrix_id: user_id),
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
    with %{local_id: from_matrix_id} <-
           Kazarma.Address.get_user(ap_id: from_ap_id),
         %{local_id: to_matrix_id} <- Kazarma.Address.get_user(ap_id: to_ap_id),
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
