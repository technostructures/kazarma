# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.ActorOutbox do
  @moduledoc """
  This room type represents "inboxes and outboxes", in ActivityPub terminology, for ActivityPub actors.

  - on ActivityPub, they are `Post`s sent to the `#Public` AP ID;
  - on Matrix, they are messages in a public room, created by the AP puppet, with alias `#user:server`.
    Public activities sent by the actor are forwarded by their puppet.
    Messages sent by Matrix users are either replies to public activities, or public activities mentioning the actor.
  """
  alias ActivityPub.Object
  alias Kazarma.ActivityPub.Collection
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias MatrixAppService.Bridge.Room

  def create_from_ap(
        %{
          object: %Object{
            data:
              %{
                "id" => object_id,
                "actor" => from_id
              } = object_data
          }
        } = _activity
      ) do
    Logger.debug("Received public Note activity")

    with {:ok, from_matrix_id} <- Address.ap_id_to_matrix(from_id),
         %MatrixAppService.Bridge.Room{local_id: room_id} <-
           get_room_for_public_create(object_data),
         Client.join(from_matrix_id, room_id),
         attachments = Map.get(object_data, "attachment"),
         {:ok, event_id} <-
           Activity.send_message_and_attachment(from_matrix_id, room_id, object_data, attachments),
         {:ok, _} <-
           Bridge.create_event(%{
             local_id: event_id,
             remote_id: object_id,
             room_id: room_id
           }) do
      :ok
    end
  end

  def create_from_ap(%{
        data: %{"to" => to_list, "actor" => from_id},
        object: %Object{
          data: %{"id" => object_id, "attributedTo" => attributed_to} = object_data
        }
      }) do
    Logger.debug("Received public Video activity")

    with %{"id" => person_sender} <-
           Enum.find(attributed_to, fn
             %{"type" => "Person"} -> true
             _ -> false
           end),
         %{"id" => channel_sender} <-
           Enum.find(attributed_to, fn
             %{"type" => "Group"} -> true
             _ -> false
           end),
         attributed_list = [channel_sender, person_sender],
         {:ok, from_matrix_id} <- Address.ap_id_to_matrix(channel_sender) do
      for attributed <- attributed_list do
        with {:ok, %Room{local_id: room_id}} <-
               get_or_create_outbox(:ap_id),
             Client.join(from_matrix_id, room_id),
             {:ok, event_id} =
               Client.send_message_for_video_object(room_id, from_matrix_id, object_data),
             {:ok, _} <-
               Bridge.create_event(%{
                 local_id: event_id,
                 remote_id: object_id,
                 room_id: room_id
               }) do
          :ok
        end
      end
    end
  end

  def create_from_ap(
        %{
          data: %{
            "to" => to,
            "object" => %{"id" => object_id, "attributedTo" => attributed_to_id} = object_data
          }
        } = _activity
      ) do
    Logger.debug("Received public Event activity")

    with {:ok, attributed_to_matrix_id} <- Kazarma.Address.ap_id_to_matrix(attributed_to_id),
         {:ok, %MatrixAppService.Bridge.Room{local_id: room_id}} <-
           get_or_create_outbox(attributed_to_id),
         Kazarma.Matrix.Client.join(attributed_to_matrix_id, room_id),
         {:ok, event_id} <-
           Client.send_message_for_event_object(room_id, attributed_to_matrix_id, object_data),
         {:ok, _} <-
           Bridge.create_event(%{
             local_id: event_id,
             remote_id: object_id,
             room_id: room_id
           }) do
      :ok
    end
  end

  defp get_room_for_public_create(%{"inReplyTo" => reply_to_ap_id} = object_data) do
    case Bridge.get_events_by_remote_id(reply_to_ap_id) do
      [%BridgeEvent{room_id: replied_to_room_id} | _] ->
        case Bridge.get_room_by_local_id(replied_to_room_id) do
          %Room{data: %{"type" => "outbox"}} = room -> room
          _ -> get_room_for_public_create(Map.delete(object_data, "inReplyTo"))
        end

      _ ->
        get_room_for_public_create(Map.delete(object_data, "inReplyTo"))
    end
  end

  defp get_room_for_public_create(%{"actor" => from_id}) do
    case get_or_create_outbox(from_id) do
      {:ok, room} ->
        room

      _ ->
        nil
    end
  end

  def create_from_matrix(event, %Room{data: %{"type" => "outbox"}} = room, content) do
    with {:ok, sender_actor} <- Address.matrix_id_to_actor(event.sender),
         {:ok, receiver_actor} <- Address.matrix_id_to_actor(room.data["matrix_id"]),
         to = ["https://www.w3.org/ns/activitystreams#Public", receiver_actor.ap_id],
         replied_activity = Activity.get_replied_activity_if_exists(event),
         context = Activity.make_context(replied_activity),
         in_reply_to = Activity.make_in_reply_to(replied_activity),
         attachment = Activity.attachment_from_matrix_event_content(event.content),
         tags = [
           %{
             "href" => receiver_actor.ap_id,
             "name" => "@#{receiver_actor.data["preferredUsername"]}",
             "type" => "Mention"
           }
         ],
         {:ok, %{object: %Object{data: %{"id" => remote_id}}}} <-
           Activity.create(
             type: "Note",
             sender: sender_actor,
             receivers_id: to,
             context: context,
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

  def get_or_create_outbox(ap_id) do
    with {:ok, %ActivityPub.Actor{username: username} = actor} <-
           ActivityPub.Actor.get_cached_by_ap_id(ap_id),
         {:ok, matrix_id} <-
           Kazarma.Address.ap_username_to_matrix_id(username, [
             :activity_pub
           ]) do
      get_or_create_outbox(actor, matrix_id)
    end
  end

  def get_or_create_outbox(
        %ActivityPub.Actor{ap_id: ap_id, data: %{"name" => name}} = actor,
        matrix_id
      ) do
    alias = Kazarma.Address.get_matrix_id_localpart(matrix_id)

    with nil <- Kazarma.Matrix.Bridge.get_room_by_remote_id(ap_id),
         {:ok, %{"room_id" => room_id}} <-
           Kazarma.Matrix.Client.create_outbox_room(
             matrix_id,
             [],
             name,
             alias
           ),
         {:ok, room} <- insert_bridge_room(room_id, actor.ap_id, matrix_id) do
      {:ok, room}
    else
      {:error, 400, %{"errcode" => "M_ROOM_IN_USE"}} ->
        {:ok, {room_id, _}} =
          Kazarma.Matrix.Client.get_alias("##{alias}:#{Kazarma.Address.domain()}")

        insert_bridge_room(
          room_id,
          actor.ap_id,
          matrix_id
        )

      %MatrixAppService.Bridge.Room{} = room ->
        {:ok, room}
    end
  end

  defp insert_bridge_room(room_id, ap_id, matrix_id) do
    Kazarma.Matrix.Bridge.create_room(%{
      local_id: room_id,
      remote_id: ap_id,
      data: %{type: :outbox, matrix_id: matrix_id}
    })
  end
end
