# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.DirectMessage do
  @moduledoc """
  This room type represents "direct messages", in microblogging terminology.

  - on ActivityPub, they are `Post`s that are only visibile for actors mentioned in it (and in every post in the chain of replies);
  - on Matrix, they are messages in a private room.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Room

  def create_from_ap(
        %{
          data: %{"to" => to},
          object: %Object{
            data:
              %{
                "actor" => from,
                "context" => conversation
              } = object_data
          }
        } = _activity
      ) do
    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from),
         to =
           Enum.map(to, fn ap_id ->
             case Address.ap_id_to_matrix(ap_id) do
               {:ok, matrix_id} -> matrix_id
               _ -> nil
             end
           end),
         {:ok, room_id} <-
           get_or_create_conversation(conversation, matrix_id, to) do
      attachments = Map.get(object_data, "attachment")

      Activity.send_message_and_attachment(matrix_id, room_id, object_data, attachments)
    end
  end

  defp get_or_create_conversation(conversation, creator, invites, opts \\ []) do
    with nil <- Bridge.get_room_by_remote_id(conversation),
         {:ok, %{"room_id" => room_id}} <-
           Client.create_multiuser_room(creator, invites, opts),
         {:ok, room} <-
           insert_bridge_room(room_id, conversation, [
             creator | invites
           ]) do
      Kazarma.Logger.log_created_room(room,
        room_type: :direct_message,
        room_id: room_id
      )

      {:ok, room_id}
    else
      %Room{local_id: local_id, data: %{"to" => _to}} = room ->
        maybe_invite_new_users(room, creator, invites)
        {:ok, local_id}

      # {:ok, room_id} -> {:ok, room_id}
      {:error, error} ->
        {:error, error}

      _ ->
        {:error, :unknown_error}
    end
  end

  defp maybe_invite_new_users(
         %Room{local_id: room_id, data: %{"to" => already_there} = room_data} = room,
         creator,
         recipients
       ) do
    new_members = Enum.filter(recipients, fn recipient -> recipient not in already_there end)

    Enum.each(new_members, fn user_id ->
      Client.invite(room_id, creator, user_id)
    end)

    Bridge.update_room(room, %{data: %{room_data | "to" => already_there ++ new_members}})
  end

  # =======================

  def create_from_event(event, room) do
    {:ok, sender} = Address.matrix_id_to_actor(event.sender)
    fallback_reply = Bridge.get_last_event_in_room(room.local_id)

    recipients =
      List.delete(room.data["to"], event.sender)
      |> Enum.map(&Address.unchecked_matrix_id_to_actor/1)
      |> Enum.filter(&(!is_nil(&1)))

    {:ok, activity} =
      Activity.create_from_event(
        event,
        sender: sender,
        to: Enum.map(recipients, & &1.ap_id),
        additional_mentions: recipients,
        context: room.remote_id,
        fallback_reply: fallback_reply
      )

    Kazarma.Logger.log_bridged_activity(activity,
      room_type: :direct_message,
      room_id: room.local_id,
      obj_type: "Note"
    )
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
    case Bridge.get_room_by_local_id(room_id) do
      nil ->
        {:ok, inviter_actor} = Address.matrix_id_to_actor(inviter_id)

        {:ok, room} =
          insert_bridge_room(room_id, ActivityPub.Utils.generate_context_id(inviter_actor), [
            matrix_id
          ])

        Kazarma.Logger.log_created_room(room,
          room_type: :direct_message,
          room_id: room_id
        )

        {:ok, room}

      room ->
        updated_room_data = update_in(room.data["to"], &[matrix_id | &1]).data
        Bridge.update_room(room, %{"data" => updated_room_data})
    end
  end
end
