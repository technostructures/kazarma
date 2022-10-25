# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity do
  @moduledoc """
  Activity-related functions.
  """
  alias ActivityPub.Object
  alias Kazarma.Logger
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias Kazarma.Matrix.Client
  alias MatrixAppService.Event

  def create(params) do
    sender = Keyword.fetch!(params, :sender)

    object =
      %{
        "type" => Keyword.fetch!(params, :type),
        "content" => Keyword.fetch!(params, :content),
        "actor" => sender.ap_id,
        "attributedTo" => sender.ap_id,
        "to" => Keyword.fetch!(params, :receivers_id),
        "conversation" => Keyword.get(params, :context)
      }
      |> maybe_put("context", Keyword.get(params, :context))
      |> maybe_put("attachment", Keyword.get(params, :attachment))
      |> maybe_put("tag", Keyword.get(params, :tags))
      |> maybe_put("inReplyTo", Keyword.get(params, :in_reply_to))

    create_params = %{
      actor: Keyword.fetch!(params, :sender),
      context: Keyword.get(params, :context),
      to: Keyword.fetch!(params, :receivers_id),
      object: object
    }

    Logger.ap_output(object)

    {:ok, _activity} = Kazarma.ActivityPub.create(create_params)
  end

  def forward_redaction(%Event{
        room_id: room_id,
        event_id: delete_event_id,
        sender: sender_id,
        type: "m.room.redaction",
        redacts: event_id
      }) do
    Logger.debug("Forwarding deletion")

    with {:ok, actor} <- Kazarma.Address.matrix_id_to_actor(sender_id),
         %BridgeEvent{remote_id: remote_id} <-
           Kazarma.Matrix.Bridge.get_event_by_local_id(event_id),
         %Object{} = object <- ActivityPub.Object.get_by_ap_id(remote_id),
         {:ok, %{object: %ActivityPub.Object{data: %{"id" => delete_remote_id}}}} <-
           Kazarma.ActivityPub.delete(object, true, actor) do
      Kazarma.Matrix.Bridge.create_event(%{
        local_id: delete_event_id,
        remote_id: delete_remote_id,
        room_id: room_id
      })

      :ok
    end
  end

  def attachment_from_matrix_event_content(%{"msgtype" => "m.text"}), do: nil

  def attachment_from_matrix_event_content(%{
        "url" => mxc_url,
        "info" => %{"mimetype" => mimetype}
      }) do
    media_url = Kazarma.Matrix.Client.get_media_url(mxc_url)

    %{
      "mediaType" => mimetype,
      "name" => nil,
      "type" => "Document",
      "url" => [
        %{
          "href" => media_url,
          "mediaType" => mimetype,
          "type" => "Link"
        }
      ]
    }
  end

  def send_message_and_attachment(matrix_id, room_id, object_data, attachments) do
    message_source = Map.get(object_data, "source")
    message_content = Map.get(object_data, "content")

    message_body = message_source || message_content

    message_formatted_body =
      Kazarma.ActivityPub.Activity.Note.translate_activity_pub_mentions(
        message_body,
        Map.get(object_data, "tag")
      )

    message_result =
      message_body &&
        Kazarma.Matrix.Client.send_tagged_message(
          room_id,
          matrix_id,
          event_for_activity_data(object_data, message_body, message_formatted_body)
        )

    attachments_results = send_attachments(matrix_id, room_id, attachments)

    get_result([message_result | attachments_results])
  end

  defp send_attachments(from, room_id, [nil | rest]), do: send_attachments(from, room_id, rest)

  defp send_attachments(from, room_id, [attachment | rest]) do
    result =
      normalize_attachment(attachment)
      |> Client.send_attachment_message_for_ap_data(from, room_id)

    [result | send_attachments(from, room_id, rest)]
  end

  defp send_attachments(_from, _room_id, _), do: []

  defp normalize_attachment(%{"mediaType" => mimetype, "url" => [%{"href" => url} | _]}) do
    %{mimetype: mimetype, url: url}
  end

  defp normalize_attachment(%{"mediaType" => mediatype, "url" => url}) do
    %{mimetype: mediatype, url: url}
  end

  defp event_for_activity_data(%{"inReplyTo" => reply_to_ap_id}, body, formatted_body) do
    case Bridge.get_event_by_remote_id(reply_to_ap_id) do
      %BridgeEvent{local_id: event_id} ->
        Client.reply_event(event_id, body, formatted_body)

      nil ->
        {body, formatted_body}
    end
  end

  defp event_for_activity_data(_, body, formatted_body) do
    {body, formatted_body}
  end

  defp get_result([{:error, error} | _rest]), do: {:error, error}
  defp get_result([{:ok, value} | _rest]), do: {:ok, value}
  defp get_result([_anything_else | rest]), do: get_result(rest)
  defp get_result([]), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
