# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.DirectMessage do
  @moduledoc """
  This room type represents "direct messages", in microblogging terminology.

  - on ActivityPub, they are `Post`s that are only visibile for actors mentioned in it (and in every post in the chain of replies);
  - on Matrix, they are messages in a private room.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Room

  def create_from_ap(%{
        data: %{"to" => to},
        object: %Object{
          data:
            %{
              "id" => object_id,
              "actor" => from,
              "conversation" => conversation
            } = object_data
        }
      }) do
    Logger.debug("Received private Note activity (direct message)")

    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from),
         to =
           Enum.map(to, fn ap_id ->
             case Address.ap_id_to_matrix(ap_id) do
               {:ok, matrix_id} -> matrix_id
               _ -> nil
             end
           end),
         {:ok, room_id} <-
           get_or_create_conversation(conversation, matrix_id, to),
         attachments = Map.get(object_data, "attachment"),
         {:ok, event_id} <-
           Activity.send_message_and_attachment(matrix_id, room_id, object_data, attachments),
         {:ok, _} <-
           Bridge.create_event(%{
             local_id: event_id,
             remote_id: object_id,
             room_id: room_id
           }) do
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  defp get_or_create_conversation(conversation, creator, invites, opts \\ []) do
    with nil <- Bridge.get_room_by_remote_id(conversation),
         {:ok, %{"room_id" => room_id}} <-
           Client.create_multiuser_room(creator, invites, opts),
         {:ok, _} <-
           insert_bridge_room(room_id, conversation, [
             creator | invites
           ]) do
      {:ok, room_id}
    else
      %Room{local_id: local_id} -> {:ok, local_id}
      # {:ok, room_id} -> {:ok, room_id}
      {:error, error} -> {:error, error}
      _ -> {:error, :unknown_error}
    end
  end

  # =======================

  def create_from_matrix(event, %Room{data: %{"type" => "direct_message"}} = room, content) do
    with {:ok, actor} <- Address.matrix_id_to_actor(event.sender),
         replying_to =
           Activity.get_replied_activity_if_exists(event) ||
             Bridge.get_last_event_in_room(room.local_id),
         in_reply_to = Activity.make_in_reply_to(replying_to),
         to =
           List.delete(room.data["to"], event.sender)
           |> Enum.map(&Address.unchecked_matrix_id_to_actor/1)
           |> Enum.filter(&(!is_nil(&1))),
         to_ap_id = Enum.map(to, & &1.ap_id),
         attachment = Activity.attachment_from_matrix_event_content(event.content),
         tags = Enum.map(to, &Activity.mention_tag_for_actor/1),
         {:ok, %{object: %Object{data: %{"id" => remote_id}}}} <-
           Activity.create(
             type: "Note",
             sender: actor,
             receivers_id: to_ap_id,
             context: room.remote_id,
             in_reply_to: in_reply_to,
             content: content,
             attachment: attachment,
             tags: tags
           ) do
      Bridge.create_event(%{
        local_id: event.event_id,
        remote_id: remote_id,
        room_id: event.room_id
      })

      :ok
    end
  end

  def handle_puppet_invite(matrix_id, inviter_id, room_id) do
    with {:ok, _actor} <- Address.matrix_id_to_actor(matrix_id, [:activity_pub]),
         # @TODO maybe update if bridge room exist (new context/conversation)
         {:ok, _room} <-
           join_or_create_bridge_room(matrix_id, inviter_id, room_id),
         _ <- Client.join(matrix_id, room_id) do
      :ok
    end
  end

  defp insert_bridge_room(room_id, conversation, participants) do
    Bridge.create_room(%{
      local_id: room_id,
      remote_id: conversation,
      data: %{type: :direct_message, to: participants}
    })
  end

  defp join_or_create_bridge_room(matrix_id, inviter_id, room_id) do
    room =
      case Bridge.get_room_by_local_id(room_id) do
        nil ->
          {:ok, inviter_actor} = Address.matrix_id_to_actor(inviter_id)

          {:ok, room} =
            insert_bridge_room(room_id, ActivityPub.Utils.generate_context_id(inviter_actor), [])

          room

        room ->
          room
      end

    updated_room_data = update_in(room.data["to"], &[matrix_id | &1]).data
    Bridge.update_room(room, %{"data" => updated_room_data})
  end
end
