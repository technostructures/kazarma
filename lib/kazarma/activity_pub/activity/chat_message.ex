# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity.ChatMessage do
  @moduledoc """
  Functions for ChatMessage activities, used by Pleroma for its chat system.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event
  require Logger

  def create(sender, receiver_id, content, attachment \\ nil) do
    object = %{
      "type" => "ChatMessage",
      "content" => content,
      "actor" => sender.ap_id,
      "attributedTo" => sender.ap_id,
      "to" => [receiver_id]
    }

    Logger.error(inspect(attachment))

    object =
      if is_nil(attachment) do
        object
      else
        Map.put(object, "attachment", attachment)
      end

    params = %{
      actor: sender,
      context: nil,
      object: object,
      to: [receiver_id]
    }

    Kazarma.ActivityPub.create(params)
  end

  def forward_create_to_matrix(%{
        data: %{
          "actor" => from_id,
          "to" => [to_id]
        },
        object: %Object{
          data:
            %{
              "content" => body
            } = object_data
        }
      }) do
    Logger.debug("Received ChatMessage activity")

    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from_id),
         {:ok, room_id} <-
           get_or_create_direct_room(from_id, to_id),
         {:ok, _} <-
           Kazarma.Matrix.Client.send_tagged_message(
             room_id,
             matrix_id,
             body
           ) do
      send_attachment(matrix_id, room_id, Map.get(object_data, "attachment"))

      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def forward_create_to_matrix(_), do: :ok

  def forward_create_to_activitypub(
        %Event{
          sender: sender,
          type: "m.room.message",
          content:
            %{
              "body" => body
            } = content
        },
        %Room{data: %{"type" => "chat_message", "to_ap_id" => remote_id}}
      ) do
    with {:ok, username} <- Kazarma.Address.matrix_id_to_ap_username(sender),
         {:ok, actor} <- ActivityPub.Actor.get_or_fetch_by_username(username) do
      attachment = Kazarma.ActivityPub.Activity.attachment_from_matrix_event_content(content)

      create(actor, remote_id, body, attachment)
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
end
