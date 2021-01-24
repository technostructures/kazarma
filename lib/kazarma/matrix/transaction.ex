defmodule Kazarma.Matrix.Transaction do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.Transaction`.
  """
  @behaviour MatrixAppService.Adapter.Transaction
  require Logger
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

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
      # room = Bridge.get_room_by_local_id(room_id) || Bridge.create_room(local_id: room_id, )
      with %Room{} = room <- Bridge.get_room_by_local_id(room_id) do
        forward_event(event, room)
      end
    end
  rescue
    # for development, we prefere acknoledging transactions even if processing them fails
    err ->
      Logger.error(Exception.format(:error, err, __STACKTRACE__))
      :ok
  end

  # %{"access_token" => "MDAyMGxvY2F0aW9uIG1hdHJpeC5pbWFnby5sb2NhbAowMDEzaWRlbnRpZmllciBrZXkKMDAxMGNpZCBnZW4gPSAxCjAwMmNjaWQgdXNlcl9pZCA9IEBhbGljZTptYXRyaXguaW1hZ28ubG9jYWwKMDAxNmNpZCB0eXBlID0gYWNjZXNzCjAwMjFjaWQgbm9uY2UgPSBjcX4jazVTUDNeUlk2WnRECjAwMmZzaWduYXR1cmUg_K2biF-xm5ue7985RkAomVadF7yfy3UiEpH-e15m0esK", "events" => [%{"age" => 802, "content" => %{"is_direct" => true, "membership" => "invite"}, "event_id" => "$Z4mzNi1CtkGqKAvHc_VEkxeqJ1Nr-Yzr6_77hB0hBXw", "origin_server_ts" => 1610182036132, "room_id" => "!gvcurdLVxqoQvwaRom:kazarma.local", "sender" => "@muser90:kazarma.local", "state_key" => "@ap_pluser91=pleroma.local:kazarma.local", "type" => "m.room.member", "unsigned" => %{"age" => 802}, "user_id" => "@muser90:kazarma.local"}], "txn_id" => "93"}

  def new_event(%Event{
        type: "m.room.member",
        content: %{"membership" => "invite", "is_direct" => true},
        room_id: room_id,
        sender: sender,
        state_key: "@ap_" <> _rest = user_id
      }) do
    {:ok, actor} = Kazarma.ActivityPub.Actor.get_by_matrix_id(user_id)
    Bridge.create_room(%{local_id: room_id, data: %{type: :chat_message, to_ap: actor.ap_id}})
    Polyjuice.Client.Room.join(MatrixAppService.Client.client(user_id: user_id), room_id)
    :ok
  end

  def new_event(%Event{
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: room_id,
        sender: sender,
        state_key: "@ap_" <> _rest = user_id
      }) do
    # {:ok, actor} = Kazarma.ActivityPub.Actor.get_by_matrix_id(user_id)

    room =
      case Bridge.get_room_by_local_id(room_id) do
        nil ->
          {:ok, room} =
            Bridge.create_room(%{
              local_id: room_id,
              remote_id: ActivityPub.Utils.generate_context_id(),
              data: %{type: :note, to: []}
            })

          room

        room ->
          room
      end

    updated_room_data = update_in(room.data["to"], &[user_id | &1]).data
    {:ok, b} = Bridge.update_room(room, %{"data" => updated_room_data})
    Polyjuice.Client.Room.join(MatrixAppService.Client.client(user_id: user_id), room_id)
    :ok
  end

  def new_event(%Event{type: type} = event) do
    Logger.debug("Received #{type} from Synapse")
    Logger.debug(inspect(event))
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
