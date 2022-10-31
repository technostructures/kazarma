# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.Chat do
  @moduledoc """
  Functions for ChatMessage activities, used by Pleroma for its chat system.
  """
  alias ActivityPub.Object
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  def create_from_ap(%{
        data: %{
          "actor" => from_id,
          "to" => [to_id]
        },
        object: %Object{
          data:
            %{
              "content" => _body,
              "id" => object_id
            } = object_data
        }
      }) do
    Logger.debug("Received ChatMessage activity to forward to Matrix")

    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from_id),
         {:ok, room_id} <-
           get_or_create_direct_room(from_id, to_id),
         attachment = Map.get(object_data, "attachment"),
         {:ok, event_id} <-
           Activity.send_message_and_attachment(matrix_id, room_id, object_data, [attachment]),
         {:ok, _} <-
           Kazarma.Matrix.Bridge.create_event(%{
             local_id: event_id,
             remote_id: object_id,
             room_id: room_id
           }) do
      :ok
    end
  end

  def create_from_matrix(
        %Event{
          event_id: event_id,
          room_id: room_id,
          sender: sender,
          type: "m.room.message",
          content: event_content
        },
        %Room{data: %{"type" => "chat_message", "to_ap_id" => remote_id}},
        text_content
      ) do
    Logger.debug("Forwarding ChatMessage creation")

    with {:ok, username} <- Kazarma.Address.matrix_id_to_ap_username(sender),
         {:ok, actor} <- ActivityPub.Actor.get_or_fetch_by_username(username),
         attachment =
           Kazarma.ActivityPub.Activity.attachment_from_matrix_event_content(event_content),
         {:ok, %{object: %ActivityPub.Object{data: %{"id" => remote_id}}}} <-
           Activity.create(
             type: "ChatMessage",
             sender: actor,
             receivers_id: [remote_id],
             content: text_content,
             attachment: attachment
           ) do
      Kazarma.Matrix.Bridge.create_event(%{
        local_id: event_id,
        remote_id: remote_id,
        room_id: room_id
      })

      :ok
    end
  end

  def create_from_matrix(_), do: :ok

  def handle_puppet_invite(user_id, sender_id, room_id) do
    Kazarma.Matrix.Client.join(user_id, room_id)
    create_bridge_room(user_id, room_id)
    Kazarma.Matrix.Client.put_new_direct_room_data(user_id, sender_id, room_id)
  end

  defp create_bridge_room(user_id, room_id) do
    with {:ok, actor} <- Kazarma.Address.matrix_id_to_actor(user_id, [:activity_pub]),
         {:ok, _room} <-
           Bridge.create_room(%{
             local_id: room_id,
             data: %{"type" => "chat_message", "to_ap_id" => actor.ap_id}
           }) do
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
         {:ok, _} <- Kazarma.Matrix.Bridge.insert_chat_message_bridge_room(room_id, from_ap_id) do
      {:ok, room_id}
    else
      {:ok, room_id} -> {:ok, room_id}
      {:error, error} -> {:error, error}
    end
  end
end
