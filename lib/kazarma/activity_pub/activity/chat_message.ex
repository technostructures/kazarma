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

    ActivityPub.create(params)
  end

  def forward_to_activitypub(
        %Event{
          sender: sender,
          type: "m.room.message",
          content: %{"msgtype" => "m.text", "body" => content}
        },
        %Room{data: %{"type" => "chat_message", "to_ap" => ap_id}}
      ) do
    {:ok, actor} = ActivityPub.Actor.get_cached_by_ap_id(Kazarma.Address.matrix_to_ap(sender))

    create(actor, ap_id, content)
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

    with {:ok, room_id} <-
           get_or_create_direct_room(from_id, to_id),
         {:ok, _} <-
           Kazarma.Matrix.Client.send_tagged_message(room_id, Address.ap_to_matrix(from_id), body) do
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def accept_puppet_invitation(user_id, room_id) do
    {:ok, actor} = Kazarma.ActivityPub.Actor.get_by_matrix_id(user_id)
    Bridge.create_room(%{local_id: room_id, data: %{type: :chat_message, to_ap: actor.ap_id}})
    Polyjuice.Client.Room.join(MatrixAppService.Client.client(user_id: user_id), room_id)
  end

  defp get_or_create_direct_room(from_ap_id, to_ap_id) do
    from_matrix_id = Address.ap_to_matrix(from_ap_id)
    to_matrix_id = Address.ap_to_matrix(to_ap_id)
    # Logger.debug("from " <> inspect(from_matrix_id) <> " to " <> inspect(to_matrix_id))

    with {:error, :not_found} <-
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
