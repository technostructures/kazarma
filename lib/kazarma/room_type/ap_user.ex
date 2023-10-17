# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomType.ApUser do
  @moduledoc """
  This room type represents "inboxes and outboxes", in ActivityPub terminology, for ActivityPub actors.

  - on ActivityPub, they are `Post`s sent to the `#Public` AP ID;
  - on Matrix, they are messages in a public room, created by the AP puppet, with alias `#user:server`.
    Public activities sent by the actor are forwarded by their puppet.
    Messages sent by Matrix users are either replies to public activities, or public activities mentioning the actor.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias MatrixAppService.Bridge.Room

  def create_from_ap(
        %{
          object: %Object{
            data:
              %{
                "type" => "Note",
                "actor" => from_id
              } = object_data
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity,
      obj_type: "Note",
      label: "Public Note activity"
    )

    with {:ok, from_matrix_id} <- Address.ap_id_to_matrix(from_id),
         %MatrixAppService.Bridge.Room{local_id: room_id, data: %{"type" => "ap_user"}} <-
           get_room_for_public_create(object_data) do
      Client.join(from_matrix_id, room_id)

      attachments = Map.get(object_data, "attachment")

      Activity.send_message_and_attachment(from_matrix_id, room_id, object_data, attachments)
    end
  end

  def create_from_ap(
        %{
          data: %{"to" => _to_list, "actor" => _from_id},
          object: %Object{
            data:
              %{
                "type" => "Video",
                "attributedTo" => attributed_to
              } = object_data
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity,
      obj_type: "Video",
      label: "Public Video activity"
    )

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
        with {:ok, %Room{local_id: room_id, data: %{"type" => "ap_user"}}} <-
               get_outbox(attributed) do
          Client.join(from_matrix_id, room_id)

          Client.send_message_for_video_object(room_id, from_matrix_id, object_data)
        end
      end
    end
  end

  def create_from_ap(
        %{
          data: %{
            "to" => _to,
            "object" => %{"attributedTo" => attributed_to_id} = object_data
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity,
      obj_type: "Event",
      label: "Public Event activity"
    )

    with {:ok, attributed_to_matrix_id} <- Kazarma.Address.ap_id_to_matrix(attributed_to_id),
         {:ok, %MatrixAppService.Bridge.Room{local_id: room_id, data: %{"type" => "ap_user"}}} <-
           get_outbox(attributed_to_id) do
      Kazarma.Matrix.Client.join(attributed_to_matrix_id, room_id)

      Client.send_message_for_event_object(room_id, attributed_to_matrix_id, object_data)
    end
  end

  defp get_room_for_public_create(%{"inReplyTo" => reply_to_ap_id} = object_data)
       when not is_nil(reply_to_ap_id) do
    case Bridge.get_events_by_remote_id(reply_to_ap_id) do
      [%BridgeEvent{room_id: replied_to_room_id} | _] ->
        case Bridge.get_room_by_local_id(replied_to_room_id) do
          %Room{data: %{"type" => "ap_user"}} = room ->
            get_room_for_public_create(Map.delete(object_data, "inReplyTo")) && room

          _ ->
            get_room_for_public_create(Map.delete(object_data, "inReplyTo"))
        end

      _ ->
        get_room_for_public_create(Map.delete(object_data, "inReplyTo"))
    end
  end

  defp get_room_for_public_create(%{"actor" => from_id}) do
    case get_outbox(from_id) do
      {:ok, room} ->
        room

      _ ->
        nil
    end
  end

  def create_from_event(event, room) do
    {:ok, sender} = Address.matrix_id_to_actor(event.sender)
    {:ok, receiver} = Address.matrix_id_to_actor(room.data["matrix_id"])

    {:ok, activity} =
      Activity.create_from_event(
        event,
        sender: sender,
        to: ["https://www.w3.org/ns/activitystreams#Public", receiver.ap_id],
        additional_mentions: [receiver]
      )

    Kazarma.Logger.log_bridged_activity(activity,
      room_type: :ap_user,
      room_id: room.local_id
    )
  end

  def get_outbox(ap_id) do
    case Bridge.get_room_by_remote_id(ap_id) do
      %MatrixAppService.Bridge.Room{} = room ->
        {:ok, room}

      nil ->
        {:error, :not_found}
    end
  end

  def create_outbox(ap_id) when is_binary(ap_id) do
    case ActivityPub.Actor.get_cached_by_ap_id(ap_id) do
      {:ok, actor} -> create_outbox(actor)
      error -> error
    end
  end

  def create_outbox(
        %ActivityPub.Actor{username: username, ap_id: ap_id, data: %{"name" => name}} = actor
      ) do
    case Bridge.get_room_by_remote_id(ap_id) do
      nil ->
        {:ok, matrix_id} = Kazarma.Address.ap_username_to_matrix_id(username, [:activity_pub])
        alias = Kazarma.Address.get_matrix_id_localpart(matrix_id)

        case Kazarma.Matrix.Client.create_outbox_room(
               matrix_id,
               [],
               name,
               alias
             ) do
          {:ok, %{"room_id" => room_id}} ->
            {:ok, room} = insert_bridge_room(room_id, actor.ap_id, matrix_id)

            Kazarma.Logger.log_created_room(room,
              room_type: :ap_room,
              room_id: room_id
            )

            send_emote_bridging_starts(matrix_id, room_id)

            {:ok, room}

          # @TODO use the Bridge.Room to know if the room already exists
          {:error, 400, %{"errcode" => "M_ROOM_IN_USE"}} ->
            {:ok, {room_id, _}} =
              Kazarma.Matrix.Client.get_alias("##{alias}:#{Kazarma.Address.domain()}")

            {:ok, room} =
              insert_bridge_room(
                room_id,
                actor.ap_id,
                matrix_id
              )

            Kazarma.Logger.log_created_room(room,
              room_type: :ap_room,
              room_id: room_id
            )

            send_emote_bridging_starts(matrix_id, room_id)

            {:ok, room}
        end

      %MatrixAppService.Bridge.Room{data: %{"type" => "ap_user"}} = room ->
        {:ok, room}

      %MatrixAppService.Bridge.Room{
        data: %{"type" => "deactivated_ap_user"} = data,
        local_id: room_id
      } = room ->
        Bridge.update_room(room, %{data: %{data | "type" => :ap_user}})

        {:ok, matrix_id} = Kazarma.Address.ap_username_to_matrix_id(username, [:activity_pub])

        send_emote_bridging_starts(matrix_id, room_id)
        {:ok, room}
    end
  end

  def deactivate_outbox(%ActivityPub.Actor{ap_id: ap_id, username: username}) do
    case Bridge.get_room_by_remote_id(ap_id) do
      %MatrixAppService.Bridge.Room{data: data, local_id: room_id} = room ->
        Bridge.update_room(room, %{data: %{data | "type" => :deactivated_ap_user}})

        {:ok, matrix_id} = Kazarma.Address.ap_username_to_matrix_id(username, [:activity_pub])

        send_emote_bridging_stops(matrix_id, room_id)

        {:ok, room}

      _ ->
        :error
    end
  end

  defp send_emote_bridging_starts(matrix_id, room_id) do
    Kazarma.Matrix.Client.send_tagged_message(
      room_id,
      matrix_id,
      %{
        "msgtype" => "m.emote",
        "body" => "has started bridging their public activity"
      }
    )
  end

  defp send_emote_bridging_stops(matrix_id, room_id) do
    Kazarma.Matrix.Client.send_tagged_message(
      room_id,
      matrix_id,
      %{
        "msgtype" => "m.emote",
        "body" => "has stopped bridging their public activity"
      }
    )
  end

  defp insert_bridge_room(room_id, ap_id, matrix_id) do
    Bridge.create_room(%{
      local_id: room_id,
      remote_id: ap_id,
      data: %{type: :ap_user, matrix_id: matrix_id}
    })
  end
end
