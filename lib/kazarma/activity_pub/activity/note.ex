defmodule Kazarma.ActivityPub.Activity.Note do
  @moduledoc """
  Functions for Note activities, used by Mastodon and Pleroma for toots.
  """
  require Logger
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  def create(sender, receivers_id, context, content) do
    object = %{
      "type" => "Note",
      "content" => content,
      "actor" => sender.ap_id,
      "attributedTo" => sender.ap_id,
      "to" => receivers_id,
      "context" => context,
      "conversation" => context
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
      context: context,
      object: object,
      to: receivers_id
    }

    {:ok, _activity} = Kazarma.ActivityPub.create(params)
  end

  def forward_to_matrix(%{
        data: %{"to" => to},
        object: %Object{
          data: %{
            "source" => source,
            "actor" => from,
            "conversation" => conversation
          }
        }
      }) do
    Logger.debug("Received Note activity")

    from = Address.ap_to_matrix(from)
    to = Enum.map(to, &Address.ap_to_matrix/1)

    with {:ok, room_id} <-
           get_or_create_conversation(conversation, from, to),
         {:ok, _} <-
           Kazarma.Matrix.Client.send_tagged_message(room_id, from, source) do
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def forward_to_activitypub(
        %Event{
          content: %{"body" => content, "msgtype" => "m.text"},
          # room_id: "!TpRetYdVcCUBdZmZLZ:kazarma.local",
          sender: sender,
          type: "m.room.message"
        },
        %Room{
          data: %{"type" => "note", "to" => to},
          # local_id: "!TpRetYdVcCUBdZmZLZ:kazarma.local",
          remote_id: remote_id
        }
      ) do
    {:ok, actor} = Kazarma.ActivityPub.Actor.get_by_matrix_id(sender)

    to =
      List.delete(to, sender)
      |> Enum.map(fn matrix_id ->
        case Kazarma.ActivityPub.Actor.get_by_matrix_id(matrix_id) do
          {:ok, actor} -> actor.ap_id
          _ -> nil
        end
      end)

    create(actor, to, remote_id, content)
  end

  def accept_puppet_invitation(user_id, room_id) do
    with {:ok, _actor} <- Kazarma.Address.puppet_matrix_id_to_actor(user_id),
         {:ok, _room} <-
           Kazarma.Matrix.Bridge.join_or_create_note_bridge_room(room_id, user_id),
         _ <- Kazarma.Matrix.Client.join(user_id, room_id) do
      :ok
    end
  end

  defp get_or_create_conversation(conversation, creator, invites) do
    with nil <- Kazarma.Matrix.Bridge.get_room_by_remote_id(conversation),
         {:ok, %{"room_id" => room_id}} <-
           Kazarma.Matrix.Client.create_multiuser_room(creator, invites),
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
end
