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

    with {:ok, from_matrix_id} <- Address.ap_id_to_matrix(from_id),
         {:ok, %MatrixAppService.Bridge.Room{local_id: room_id}} <-
           Collection.get_or_create_outbox({:ap_id, from_id}),
         Client.join(from_matrix_id, room_id),
         {:ok, event_id} <-
           send_message_and_attachment(from_matrix_id, room_id, object_data),
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

  def send_message_and_attachment(matrix_id, room_id, object_data) do
    case {call_if_not_nil(
            Map.get(object_data, "source"),
            Map.get(object_data, "content"),
            fn source, content ->
              Client.send_tagged_message(
                room_id,
                matrix_id,
                source || content,
                content || source
              )
            end
          ),
          call_if_not_nil(Map.get(object_data, "attachment"), fn attachment ->
            send_attachments(matrix_id, room_id, attachment)
            |> get_result()
          end)} do
      {nil, nil} -> {:error, :no_message_to_send}
      {{:ok, event_id}, _} -> {:ok, event_id}
      {_, {:ok, event_id}} -> {:ok, event_id}
      {{:error, err}, _} -> {:error, err}
      {_, {:error, err}} -> {:error, err}
    end
  end

  def unchecked_matrix_id_to_actor(matrix_id) do
    case Address.matrix_id_to_actor(matrix_id) do
      {:ok, actor} -> actor
      _ -> nil
    end
  end

  def forward(event, %Room{data: %{"type" => "note"}} = room) do
    with {:ok, actor} <- Address.matrix_id_to_actor(event.sender),
         %BridgeEvent{remote_id: in_reply_to} <- Bridge.get_last_event_in_room(room.local_id),
         to =
           List.delete(room.data["to"], event.sender)
           |> Enum.map(&unchecked_matrix_id_to_actor/1)
           |> Enum.filter(&(!is_nil(&1))),
         to_ap_id = Enum.map(to, & &1.ap_id),
         attachment = Activity.attachment_from_matrix_event_content(event.content),
         tags =
           Enum.map(to, fn actor ->
             %{
               "href" => actor.ap_id,
               "name" => "@#{actor.data["preferredUsername"]}",
               "type" => "Mention"
             }
           end),
         {:ok, %{object: %Object{data: %{"id" => remote_id}}}} <-
           Activity.create(
             type: "Note",
             sender: actor,
             receivers_id: to_ap_id,
             context: room.remote_id,
             in_reply_to: in_reply_to,
             content: event.content["body"],
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

  def forward(event, %Room{data: %{"type" => "outbox"}} = room) do
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
             content: event.content["body"],
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
    case Bridge.get_event_by_local_id(event_id) do
      %BridgeEvent{remote_id: ap_id} ->
        Object.get_cached_by_ap_id(ap_id)

      _ ->
        nil
    end
  end

  defp get_replied_activity_if_exists(_), do: nil

  defp make_context(%Object{data: %{"context" => context}}), do: context

  defp make_context(_), do: ActivityPub.Utils.generate_context_id()

  defp make_in_reply_to(%Object{data: %{"id" => ap_id}}), do: ap_id

  defp make_in_reply_to(_), do: nil

  defp send_attachments(from, room_id, [attachment | rest]) do
    result =
      normalize_attachment(attachment)
      |> Client.send_attachment_message_for_ap_data(from, room_id)

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

  defp call_if_not_nil(value1, value2, fun) do
    fun.(value1, value2)
  end

  defp call_if_not_nil(nil, _fun), do: nil
  defp call_if_not_nil([], _fun), do: nil

  defp call_if_not_nil(value, fun) do
    fun.(value)
  end
end
