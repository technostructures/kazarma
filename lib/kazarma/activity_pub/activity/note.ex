# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity.Note do
  @moduledoc """
  Functions for Note activities, used by Mastodon and Pleroma for toots.
  """
  alias Kazarma.Logger
  alias ActivityPub.Object
  alias Kazarma.Address
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  def create(sender, receivers_id, context, content, attachment \\ nil, tags \\ nil) do
    object = %{
      "type" => "Note",
      "content" => content,
      "actor" => sender.ap_id,
      "attributedTo" => sender.ap_id,
      "to" => receivers_id,
      "context" => context,
      "conversation" => context
    }

    object =
      if is_nil(attachment) do
        object
      else
        Map.put(object, "attachment", attachment)
      end

    object =
      if is_nil(tags) do
        object
      else
        Map.put(object, "tag", tags)
      end

    params = %{
      actor: sender,
      context: context,
      object: object,
      to: receivers_id
    }

    Logger.ap_output(params)

    {:ok, _activity} = Kazarma.ActivityPub.create(params)
  end

  def forward_create_to_matrix(%{data: %{"to" => to}} = activity) do
    if "https://www.w3.org/ns/activitystreams#Public" in to do
      forward_public_create_to_matrix(activity)
    else
      forward_private_create_to_matrix(activity)
    end
  end

  def forward_create_to_matrix(_), do: :ok

  def forward_public_create_to_matrix(%{
        object: %Object{
          data:
            %{
              "id" => object_id,
              "actor" => from_id
            } = object_data
        }
      }) do
    Logger.debug("Received public Note activity")

    with {:ok, from_matrix_id} <- Kazarma.Address.ap_id_to_matrix(from_id),
         {:ok, %MatrixAppService.Bridge.Room{local_id: room_id}} <-
           Kazarma.ActivityPub.Collection.get_or_create_outbox({:ap_id, from_id}),
         Kazarma.Matrix.Client.join(from_matrix_id, room_id),
         {:ok, event_id} <-
           send_message_and_attachment(from_matrix_id, room_id, object_data),
         {:ok, _} <-
           Kazarma.Matrix.Bridge.create_event(%{
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
    Logger.debug("Received private Note activity")

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
         {:ok, event_id} <-
           send_message_and_attachment(matrix_id, room_id, object_data),
         {:ok, _} <-
           Kazarma.Matrix.Bridge.create_event(%{
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

  def send_message_and_attachment(matrix_id, room_id, object_data) do
    case {call_if_not_nil(
            Map.get(object_data, "source"),
            Map.get(object_data, "content"),
            fn source, content ->
              Kazarma.Matrix.Client.send_tagged_message(
                room_id,
                matrix_id,
                source,
                content
              )
            end
          ),
          call_if_not_nil(Map.get(object_data, "attachment"), fn attachment ->
            send_attachments(matrix_id, room_id, attachment)
            |> get_result()
          end)} do
      {nil, nil} -> {:error, :no_message_to_send}
      {{:error, err}, _} -> {:error, err}
      {_, {:error, err}} -> {:error, err}
      {{:ok, event_id}, _} -> {:ok, event_id}
      {_, {:ok, event_id}} -> {:ok, event_id}
    end
  end

  def ap_id_of_matrix(matrix_id) do
    case Kazarma.Address.matrix_id_to_actor(matrix_id) do
      {:ok, actor} -> actor.ap_id
      _ -> nil
    end
  end

  def forward(event, %Room{data: %{"type" => "note"}} = room) do
    with {:ok, actor} <- Kazarma.Address.matrix_id_to_actor(event.sender),
         to = List.delete(room.data["to"], event.sender) |> Enum.map(&ap_id_of_matrix(&1)),
         attachment =
           Kazarma.ActivityPub.Activity.attachment_from_matrix_event_content(event.content),
         {:ok, %{object: %ActivityPub.Object{data: %{"id" => remote_id}}}} <-
           create(actor, to, room.remote_id, event.content["body"], attachment) do
      Kazarma.Matrix.Bridge.create_event(%{
        local_id: event.event_id,
        remote_id: remote_id,
        room_id: event.room_id
      })

      :ok
    end
  end

  def forward(
        %Event{content: %{"m.relates_to" => %{"m.in_reply_to" => replied_event}}} = event,
        %Room{data: %{"type" => "outbox"}} = room
      ) do
    # TODO: Fallback to normal message if we can't find the replied activity
    Logger.debug("Replying to:")
    Logger.debug(Kazarma.Matrix.Bridge.get_event_by_local_id(replied_event["event_id"]))

    context = ActivityPub.Utils.generate_context_id()
    {:ok, sender_actor} = Kazarma.Address.matrix_id_to_actor(event.sender)
    {:ok, receiver_actor} = Kazarma.Address.matrix_id_to_actor(room.data["matrix_id"])
    to = ["https://www.w3.org/ns/activitystreams#Public", receiver_actor.ap_id]

    obj = %{
      actor: sender_actor,
      context: context,
      to: to,
      object: %{
        "type" => "Note",
        "content" => event.content["body"],
        "actor" => sender_actor.ap_id,
        "attributedTo" => sender_actor.ap_id,
        "to" => to,
        "context" => context,
        "conversation" => context,
        "inReplyTo" => "http://pleroma.local/objects/87eb67ea-19f2-4e3d-89cd-fd46ed3b15d5"

        # "attachment" => Kazarma.ActivityPub.Activity.attachment_from_matrix_event_content(event.content),
        # "tag" => [
        #   %{
        #     "href" => receiver_actor.ap_id,
        #     "name" => "@#{receiver_actor.data["preferredUsername"]}",
        #     "type" => "Mention"
        #   }
        # ],
      }
    }

    Logger.ap_output(obj)

    {:ok, _activity} = Kazarma.ActivityPub.create(obj)
  end

  def forward(event, %Room{data: %{"type" => "outbox"}} = room) do
    with {:ok, sender_actor} <- Kazarma.Address.matrix_id_to_actor(event.sender),
         {:ok, receiver_actor} <- Kazarma.Address.matrix_id_to_actor(room.data["matrix_id"]),
         to = ["https://www.w3.org/ns/activitystreams#Public", receiver_actor.ap_id],
         context = ActivityPub.Utils.generate_context_id(),
         attachment =
           Kazarma.ActivityPub.Activity.attachment_from_matrix_event_content(event.content),
         tags = [
           %{
             "href" => receiver_actor.ap_id,
             "name" => "@#{receiver_actor.data["preferredUsername"]}",
             "type" => "Mention"
           }
         ],
         {:ok, %{object: %ActivityPub.Object{data: %{"id" => remote_id}}}} <-
           create(sender_actor, to, context, event.content["body"], attachment, tags) do
      Kazarma.Matrix.Bridge.create_event(%{
        local_id: event.event_id,
        remote_id: remote_id,
        room_id: event.room_id
      })

      :ok
    end
  end

  def forward(_), do: :ok

  def accept_puppet_invitation(user_id, room_id) do
    with {:ok, _actor} <- Kazarma.Address.matrix_id_to_actor(user_id, [:activity_pub]),
         {:ok, _room} <-
           Kazarma.Matrix.Bridge.join_or_create_note_bridge_room(room_id, user_id),
         _ <- Kazarma.Matrix.Client.join(user_id, room_id) do
      :ok
    end
  end

  defp get_or_create_conversation(conversation, creator, invites, opts \\ []) do
    with nil <- Kazarma.Matrix.Bridge.get_room_by_remote_id(conversation),
         {:ok, %{"room_id" => room_id}} <-
           Kazarma.Matrix.Client.create_multiuser_room(creator, invites, opts),
         {:ok, _} <-
           Kazarma.Matrix.Bridge.insert_note_bridge_room(room_id, conversation, [
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

  defp send_attachments(from, room_id, [attachment | rest]) do
    result =
      normalize_attachment(attachment)
      |> Kazarma.Matrix.Client.send_attachment_message_for_ap_data(from, room_id)

    [result | send_attachments(from, room_id, rest)]
  end

  defp send_attachments(_from, _room_id, _), do: []

  defp normalize_attachment(%{"mediaType" => mediatype, "url" => url}) do
    %{mimetype: mediatype, url: url}
  end

  defp get_result([{:error, error} | _rest]), do: {:error, error}
  defp get_result([{:ok, value} | _rest]), do: {:ok, value}
  defp get_result([_anything_else | rest]), do: get_result(rest)
  defp get_result([]), do: nil

  defp call_if_not_nil(nil, nil, _fun), do: nil
  defp call_if_not_nil(nil, _fun), do: nil
  defp call_if_not_nil([], _fun), do: nil

  defp call_if_not_nil(value, fun) do
    fun.(value)
  end

  defp call_if_not_nil(value1, value2, fun) do
    fun.(value1, value2)
  end
end
