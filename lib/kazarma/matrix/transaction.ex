defmodule Kazarma.Matrix.Transaction do
  @behaviour MatrixAppService.Adapter.Transaction
  require Logger
  alias MatrixAppService.Event
  alias MatrixAppService.Bridge.Room
  alias Kazarma.Matrix.Bridge

  @impl MatrixAppService.Adapter.Transaction
  def new_event(%Event{
        type: "m.room.create",
        content: %{"creator" => creator_id}
      }) do
    Logger.debug("Room creation by #{creator_id}")
  end

  def new_event(%Event{
        type: "m.room.name",
        content: %{"name" => name}
      }) do
    Logger.debug("Attributing name #{name}")
  end

  def new_event(%Event{type: "m.room.message", room_id: room_id} = event) do
    Logger.debug("Received m.room.message from Synapse")

    if !is_tagged_message(event) do
      with %Room{} = room <- Bridge.get_room_by_local_id(room_id) |> IO.inspect() do
        forward_event(event, room)
      end
    end
  rescue
    # for development, we prefere acknoledging transactions even if processing them fails
    err ->
      Logger.error(Exception.format(:error, err, __STACKTRACE__))
      :ok
  end

  def new_event(%Event{type: type}) do
    Logger.debug("Received #{type} from Synapse")
  end

  defp forward_event(
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

    object = %{
      "type" => "Note",
      "content" => content,
      "actor" => actor.ap_id,
      "attributedTo" => actor.ap_id,
      "to" => to,
      "context" => remote_id,
      "conversation" => remote_id
      # "tag" => [
      #   %{
      #     "href" => "http://pleroma.local/users/mike",
      #     "name" => "@mike@pleroma.local",
      #     "type" => "Mention"
      #   }
      # ]
    }

    params = %{
      actor: actor,
      # ActivityPub.Utils.generate_context_id(),
      context: remote_id,
      object: object,
      to: to
    }

    {:ok, _activity} = ActivityPub.create(params)
  end

  defp forward_event(
         %Event{
           sender: sender,
           type: "m.room.message",
           content: %{"msgtype" => "m.text", "body" => content}
         },
         %Room{data: %{"type" => "chat_message", "to_ap" => ap_id}}
       ) do
    {:ok, actor} = ActivityPub.Actor.get_cached_by_ap_id(Kazarma.Address.matrix_to_ap(sender))

    object = %{
      "type" => "ChatMessage",
      "content" => content,
      "actor" => actor.ap_id,
      "attributedTo" => actor.ap_id,
      "to" => [ap_id]
      # "tag" => [
      #   %{
      #     "href" => "http://pleroma.local/users/mike",
      #     "name" => "@mike@pleroma.local",
      #     "type" => "Mention"
      #   }
      # ]
    }

    params = %{
      actor: actor,
      # ActivityPub.Utils.generate_context_id(),
      context: nil,
      object: object,
      to: [ap_id]
    }

    {:ok, _activity} = ActivityPub.create(params)
  end

  defp is_tagged_message(%Event{content: %{"body" => body}}) do
    String.ends_with?(body, " \ufeff")
  end

  defp is_tagged_message(_), do: false
end
