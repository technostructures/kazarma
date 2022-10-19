# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity.ChatMessage do
  @moduledoc """
  Functions for ChatMessage activities, used by Pleroma for its chat system.
  """
  alias ActivityPub.Object
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  def forward_create_to_matrix(%{
        data: %{
          "actor" => from_id,
          "to" => [to_id]
        },
        object: %Object{
          data:
            %{
              "content" => _body,
              "id" => object_id
            } = object_data
        }
      }) do
    Logger.debug("Received ChatMessage activity to forward to Matrix")

    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from_id),
         {:ok, room_id} <-
           get_or_create_direct_room(from_id, to_id),
         {:ok, event_id} <-
           send_message_and_attachment(matrix_id, room_id, object_data),
         {:ok, _} <-
           Kazarma.Matrix.Bridge.create_event(%{
             local_id: event_id,
             remote_id: object_id,
             room_id: room_id
           }) do
      :ok
    end
  end

  defp send_message_and_attachment(matrix_id, room_id, object_data) do
    case {call_if_not_nil(Map.get(object_data, "content"), fn body ->
            Kazarma.Matrix.Client.send_tagged_message(
              room_id,
              matrix_id,
              body
            )
          end),
          call_if_not_nil(Map.get(object_data, "attachment"), fn attachment ->
            send_attachment(matrix_id, room_id, attachment)
          end)} do
      {nil, nil} -> {:error, :no_message_to_send}
      {{:error, err}, _} -> {:error, err}
      {_, {:error, err}} -> {:error, err}
      {{:ok, event_id}, _} -> {:ok, event_id}
      {_, {:ok, event_id}} -> {:ok, event_id}
    end
  end

  def forward_create_to_activitypub(
        %Event{
          event_id: event_id,
          room_id: room_id,
          sender: sender,
          type: "m.room.message",
          content:
            %{
              "body" => body
            } = content
        },
        %Room{data: %{"type" => "chat_message", "to_ap_id" => remote_id}}
      ) do
    Logger.debug("Forwarding ChatMessage creation")

    with {:ok, username} <- Kazarma.Address.matrix_id_to_ap_username(sender),
         {:ok, actor} <- ActivityPub.Actor.get_or_fetch_by_username(username),
         attachment = Kazarma.ActivityPub.Activity.attachment_from_matrix_event_content(content),
         {:ok, %{object: %ActivityPub.Object{data: %{"id" => remote_id}}}} <-
           Activity.create(
             type: "ChatMessage",
             sender: actor,
             receivers_id: [remote_id],
             content: body,
             attachment: attachment
           ) do
      Kazarma.Matrix.Bridge.create_event(%{
        local_id: event_id,
        remote_id: remote_id,
        room_id: room_id
      })

      :ok
    end
  end

  def forward_create_to_activitypub(_), do: :ok

  def accept_puppet_invitation(user_id, room_id) do
    with {:ok, actor} <- Kazarma.Address.matrix_id_to_actor(user_id, [:activity_pub]),
         {:ok, _room} <-
           Bridge.create_room(%{
             local_id: room_id,
             data: %{"type" => "chat_message", "to_ap_id" => actor.ap_id}
           }),
         _ <- Kazarma.Matrix.Client.join(user_id, room_id) do
      :ok
    else
      _ -> :error
    end
  end

  defp get_or_create_direct_room(from_ap_id, to_ap_id) do
    with {:ok, from_matrix_id} <- Address.ap_id_to_matrix(from_ap_id),
         {:ok, to_matrix_id} <- Address.ap_id_to_matrix(to_ap_id),
         {:error, :not_found} <-
           Kazarma.Matrix.Client.get_direct_room(from_matrix_id, to_matrix_id),
         {:ok, %{"room_id" => room_id}} <-
           Kazarma.Matrix.Client.create_direct_room(from_matrix_id, to_matrix_id),
         {:ok, _} <- Kazarma.Matrix.Bridge.insert_chat_message_bridge_room(room_id, from_ap_id) do
      {:ok, room_id}
    else
      {:ok, room_id} -> {:ok, room_id}
      {:error, error} -> {:error, error}
    end
  end

  defp send_attachment(_from, _room_id, nil), do: nil

  defp send_attachment(from, room_id, attachment) do
    normalize_attachment(attachment)
    |> Kazarma.Matrix.Client.send_attachment_message_for_ap_data(from, room_id)
  end

  defp normalize_attachment(%{"mediaType" => mimetype, "url" => [%{"href" => url} | _]}) do
    %{mimetype: mimetype, url: url}
  end

  defp call_if_not_nil(nil, _fun), do: nil

  defp call_if_not_nil(value, fun) do
    fun.(value)
  end
end
