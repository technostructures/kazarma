# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity.Note do
  @moduledoc """
  Functions for Note activities, used by Mastodon and Pleroma for toots.
  """
  alias ActivityPub.Object
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.ActivityPub.Collection
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias Kazarma.Matrix.Client
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  def forward_create_to_matrix(%{data: %{"to" => to}} = activity) do
    if "https://www.w3.org/ns/activitystreams#Public" in to do
      forward_public_create_to_matrix(activity)
    else
      forward_private_create_to_matrix(activity)
    end
  end

  def forward_create_to_matrix(_), do: :ok

  def forward_public_create_to_matrix(
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

  def forward_private_create_to_matrix(%{
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

  def forward_private_create_to_matrix(%{
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
           Bridge.insert_collection_bridge_room(room_id, members_ap_id) do
      {:ok, room_id}
    else
      %Room{local_id: local_id} -> {:ok, local_id}
      {:error, error} -> {:error, error}
      _ -> {:error, :unknown_error}
    end
  end

  def unchecked_matrix_id_to_actor(matrix_id) do
    case Address.matrix_id_to_actor(matrix_id) do
      {:ok, actor} -> actor
      _ -> nil
    end
  end

  defp mention_tag_for_actor(actor) do
    %{
      "href" => actor.ap_id,
      "name" => "@#{actor.data["preferredUsername"]}",
      "type" => "Mention"
    }
  end

  def forward(event, %Room{data: %{"type" => "note"}} = room, content) do
    with {:ok, actor} <- Address.matrix_id_to_actor(event.sender),
         replying_to =
           get_replied_activity_if_exists(event) || Bridge.get_last_event_in_room(room.local_id),
         in_reply_to = make_in_reply_to(replying_to),
         to =
           List.delete(room.data["to"], event.sender)
           |> Enum.map(&unchecked_matrix_id_to_actor/1)
           |> Enum.filter(&(!is_nil(&1))),
         to_ap_id = Enum.map(to, & &1.ap_id),
         attachment = Activity.attachment_from_matrix_event_content(event.content),
         tags = Enum.map(to, &mention_tag_for_actor/1),
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

  def forward(event, %Room{data: %{"type" => "outbox"}} = room, content) do
    with {:ok, sender_actor} <- Address.matrix_id_to_actor(event.sender),
         {:ok, receiver_actor} <- Address.matrix_id_to_actor(room.data["matrix_id"]),
         to = ["https://www.w3.org/ns/activitystreams#Public", receiver_actor.ap_id],
         replied_activity = get_replied_activity_if_exists(event),
         context = make_context(replied_activity),
         in_reply_to = make_in_reply_to(replied_activity),
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

  def forward(event, %Room{data: %{"type" => "collection"}, remote_id: group_ap_id}, content) do
    with {:ok, sender_actor} <- Address.matrix_id_to_actor(event.sender),
         to = [group_ap_id],
         replied_activity = get_replied_activity_if_exists(event),
         context = make_context(replied_activity),
         in_reply_to = make_in_reply_to(replied_activity),
         attachment = Activity.attachment_from_matrix_event_content(event.content),
         tags = [],
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

  def forward(_), do: :ok

  def accept_puppet_invitation(user_id, room_id) do
    with {:ok, _actor} <- Address.matrix_id_to_actor(user_id, [:activity_pub]),
         {:ok, _room} <-
           Bridge.join_or_create_note_bridge_room(room_id, user_id),
         _ <- Client.join(user_id, room_id) do
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
    case Collection.get_or_create_outbox({:ap_id, from_id}) do
      {:ok, room} ->
        room

      _ ->
        nil
    end
  end

  defp get_or_create_conversation(conversation, creator, invites, opts \\ []) do
    with nil <- Bridge.get_room_by_remote_id(conversation),
         {:ok, %{"room_id" => room_id}} <-
           Client.create_multiuser_room(creator, invites, opts),
         {:ok, _} <-
           Bridge.insert_note_bridge_room(room_id, conversation, [
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

  defp get_replied_activity_if_exists(%Event{
         content: %{"m.relates_to" => %{"m.in_reply_to" => %{"event_id" => event_id}}}
       }) do
    case Bridge.get_events_by_local_id(event_id) do
      [%BridgeEvent{remote_id: ap_id} | _] ->
        Object.get_cached_by_ap_id(ap_id)

      _ ->
        nil
    end
  end

  defp get_replied_activity_if_exists(_), do: nil

  defp make_context(%Object{data: %{"context" => context}}), do: context

  defp make_context(_), do: ActivityPub.Utils.generate_context_id()

  defp make_in_reply_to(%Object{data: %{"id" => ap_id}}), do: ap_id
  defp make_in_reply_to(%BridgeEvent{remote_id: ap_id}), do: ap_id

  defp make_in_reply_to(_), do: nil
end
