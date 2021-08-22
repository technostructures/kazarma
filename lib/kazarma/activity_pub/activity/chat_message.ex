defmodule Kazarma.ActivityPub.Activity.ChatMessage do
  @moduledoc """
  Functions for ChatMessage activities, used Pleroma for its chat system.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event
  require Logger

  def create(sender, receiver_id, content) do
    object = %{
      "type" => "ChatMessage",
      "content" => content,
      "actor" => sender.ap_id,
      "attributedTo" => sender.ap_id,
      "to" => [receiver_id]
      # "tag" => [
      #   %{
      #     "href" => "http://pleroma.local/users/mike",
      #     "name" => "@mike@pleroma.local",
      #     "type" => "Mention"
      #   }
      # ]
    }

    params = %{
      actor: sender,
      # ActivityPub.Utils.generate_context_id(),
      context: nil,
      object: object,
      to: [receiver_id]
    }

    Kazarma.ActivityPub.create(params)
  end

  def forward_to_matrix(%{
        data: %{
          "actor" => from_id,
          "to" => [to_id]
        },
        object: %Object{
          data: %{
            "content" => body
          }
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
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def forward_to_activitypub(
        %Event{
          sender: sender,
          type: "m.room.message",
          content: %{"msgtype" => "m.text", "body" => content}
        },
        %Room{data: %{"type" => "chat_message", "to_ap_id" => ap_id}}
      ) do
    with {:ok, username} <- Kazarma.Address.matrix_id_to_ap_username(sender),
         {:ok, actor} <- ActivityPub.Actor.get_or_fetch_by_username(username) do
      create(actor, ap_id, content)
    end
  end

  def accept_puppet_invitation(user_id, room_id) do
    with {:ok, actor} <- Kazarma.Address.matrix_id_to_actor(user_id, [:puppet]),
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
end
