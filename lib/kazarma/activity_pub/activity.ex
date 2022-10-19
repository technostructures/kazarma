# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity do
  @moduledoc """
  Activity-related functions.
  """
  alias ActivityPub.Object
  alias Kazarma.Logger
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
