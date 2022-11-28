# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.MatrixUser do
  @moduledoc """
  Matrix Outbox rooms are rooms representing the timeline/wall of a Matrix user
  If the relevant user posts in the room, it's bridged as a public Create/Note
  If another user posts in the room, it's a public Create/Note with a mention
  Users can declare a public room as an outbox room by using the appservice bot
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Room

  def create_from_event(event, room) do
    {:ok, sender} = Address.matrix_id_to_actor(event.sender)

    if sender == room.data["matrix_id"] do
      Kazarma.ActivityPub.Activity.create_note_from_event(
        event,
        sender,
        ["https://www.w3.org/ns/activitystreams#Public"],
        []
      )
    else
      {:ok, receiver} = Address.matrix_id_to_actor(room.data["matrix_id"])

      Kazarma.ActivityPub.Activity.create_note_from_event(
        event,
        sender,
        ["https://www.w3.org/ns/activitystreams#Public", receiver.ap_id],
        [receiver]
      )
    end
  end

  def join(actor, follower_ap_id) do
    case Bridge.get_room_by_remote_id(actor.ap_id) do
      %Room{local_id: room_id, data: %{"type" => "matrix_user"}} ->
        {:ok, follower_matrix_id} = Address.ap_id_to_matrix(follower_ap_id, [:activity_pub])
        Client.join(follower_matrix_id, room_id)

      _ ->
        :ok
    end
  end

  def maybe_set_outbox_type(room_id, user_id) do
    if Client.is_administrator(room_id, user_id) do
      case Address.matrix_id_to_actor(user_id) do
        {:ok, %ActivityPub.Actor{ap_id: ap_id}} ->
          insert_bridge_room(room_id, user_id, ap_id)

        _ ->
          nil
      end
    end
  end

  # def maybe_unset_outbox_type(room_id, user_id) do
  #   if Client.is_administrator(room_id, user_id) do
  #     delete_bridge_room(room_id, user_id, ap_id)
  #   end
  # end

  defp insert_bridge_room(room_id, matrix_id, ap_id) do
    Bridge.create_room(%{
      local_id: room_id,
      remote_id: ap_id,
      data: %{type: :matrix_user, matrix_id: matrix_id}
    })
  end
end
