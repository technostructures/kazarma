# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.Collection do
  @moduledoc """
  This room type represents activities sent to "collections", in ActivityPub terminology, for instance members of a Group actor (in Mobilizon).

  - on ActivityPub, they are `Post`s sent to the collection AP ID;
  - on Matrix, they are messages in a private room, created by the Group actor puppet. Other members are invited by this puppet.
    If an AP puppet receives an Invite activity, its corresponding Matrix user is invited in the room. If they join the room, the Invite is accepted.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias MatrixAppService.Bridge.Room

  def create_from_ap(%{
        data: %{"actor" => from},
        object: %Object{
          data:
            %{
              "id" => object_id,
              "attributedTo" => group_ap_id,
              "to" => [group_members]
            } = object_data
        }
      }) do
    Logger.debug("Received private Note activity (Mobilizon style)")

    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from),
         {:ok, %{username: group_username, data: %{"name" => group_name}}} <-
           ActivityPub.Actor.get_cached_by_ap_id(group_ap_id),
         {:ok, group_matrix_id} <- Address.ap_username_to_matrix_id(group_username),
         {:ok, room_id} <-
           get_or_create_collection_room(group_members, group_matrix_id, group_name),
         :ok <- Client.invite_and_accept(room_id, group_matrix_id, matrix_id),
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

  def get_or_create_collection_room(members_ap_id, matrix_id, name) do
    with nil <- Bridge.get_room_by_remote_id(members_ap_id),
         {:ok, %{"room_id" => room_id}} <-
           Client.create_multiuser_room(matrix_id, [], name: name),
         {:ok, _} <-
           insert_bridge_room(room_id, members_ap_id) do
      {:ok, room_id}
    else
      %Room{local_id: local_id} -> {:ok, local_id}
      {:error, error} -> {:error, error}
      _ -> {:error, :unknown_error}
    end
  end

  def create_from_event(event, room) do
    {:ok, sender} = Address.matrix_id_to_actor(event.sender)

    Activity.create_from_event(
      event,
      sender: sender,
      to: [room.remote_id]
    )
  end

  # @TODO destructure event in Matrix.Transaction
  def handle_join(joiner, event, group_ap_id) do
    with %{
           unsigned: %{
             "prev_content" => %{"membership" => "invite"},
             "replaces_state" => invite_event_id
           }
         } <- event,
         %BridgeEvent{remote_id: invite_ap_id} <-
           Bridge.get_event_by_local_id(invite_event_id) do
      Kazarma.ActivityPub.accept(%{
        to: [group_ap_id],
        object: invite_ap_id,
        actor: joiner
      })
    end
  end

  defp insert_bridge_room(room_id, group) do
    Bridge.create_room(%{
      local_id: room_id,
      remote_id: group,
      data: %{type: :collection}
    })
  end
end
