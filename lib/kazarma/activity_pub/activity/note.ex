# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity.Note do
  @moduledoc """
  Functions for Note activities, used by Mastodon and Pleroma for toots.
  """
  require Logger
  alias ActivityPub.Object
  alias Kazarma.Address
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  def create(sender, receivers_id, context, content, attachment \\ nil) do
    object = %{
      "type" => "Note",
      "content" => content,
      "attachment" => attachment,
      "actor" => sender.ap_id,
      "attributedTo" => sender.ap_id,
      "to" => receivers_id,
      "context" => context,
      "conversation" => context
    }

    params = %{
      actor: sender,
      context: context,
      object: object,
      to: receivers_id
    }

    {:ok, _activity} = Kazarma.ActivityPub.create(params)
  end

  def forward_to_matrix(%{
        data: %{"to" => to},
        object: %Object{
          data:
            %{
              "actor" => from,
              "conversation" => conversation
            } = object_data
        }
      }) do
    Logger.debug("Received Note activity")

    source = object_data["source"] || object_data["content"]

    with {:ok, from} <- Address.ap_id_to_matrix(from),
         to =
           Enum.map(to, fn ap_id ->
             case Address.ap_id_to_matrix(ap_id) do
               {:ok, matrix_id} -> matrix_id
               _ -> nil
             end
           end),
         {:ok, room_id} <-
           get_or_create_conversation(conversation, from, to),
         {:ok, _} <-
           Kazarma.Matrix.Client.send_tagged_message(room_id, from, source) do
      send_attachments(from, room_id, Map.get(object_data, "attachment"))

      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def forward_to_activitypub(
        %Event{
          content:
            %{
              "body" => body
            } = content,
          sender: sender,
          type: "m.room.message"
        },
        %Room{
          data: %{"type" => "note", "to" => to},
          remote_id: remote_id
        }
      ) do
    with {:ok, actor} = Kazarma.ActivityPub.Actor.get_by_matrix_id(sender) do
      to =
        List.delete(to, sender)
        |> Enum.map(fn matrix_id ->
          case Kazarma.ActivityPub.Actor.get_by_matrix_id(matrix_id) do
            {:ok, actor} -> actor.ap_id
            _ -> nil
          end
        end)

      attachment = Kazarma.ActivityPub.Activity.attachment_from_matrix_event_content(content)

      create(actor, to, remote_id, body, attachment)
    end
  end

  def accept_puppet_invitation(user_id, room_id) do
    with {:ok, _actor} <- Kazarma.Address.matrix_id_to_actor(user_id, [:puppet]),
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
    normalize_attachment(attachment)
    |> Kazarma.Matrix.Client.send_attachment_message_for_ap_data(from, room_id)

    send_attachments(from, room_id, rest)
  end

  defp send_attachments(_from, _room_id, _), do: nil

  defp normalize_attachment(%{"mediaType" => mediatype, "url" => url}) do
    %{mimetype: mediatype, url: url}
  end
end
