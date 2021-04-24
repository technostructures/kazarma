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
      case Bridge.get_room_by_local_id(room_id) do
        %Room{data: %{"type" => "chat_message"}} = room ->
          Kazarma.ActivityPub.Activity.ChatMessage.forward_to_activitypub(event, room)

        %Room{data: %{"type" => "note"}} = room ->
          Kazarma.ActivityPub.Activity.Note.forward_to_activitypub(event, room)
      end
    end
  rescue
    # for development, we prefere acknowledging transactions even if processing them fails
    err ->
      Logger.error(Exception.format(:error, err, __STACKTRACE__))
      :ok
  end

  # %{"access_token" => "MDAyMGxvY2F0aW9uIG1hdHJpeC5pbWFnby5sb2NhbAowMDEzaWRlbnRpZmllciBrZXkKMDAxMGNpZCBnZW4gPSAxCjAwMmNjaWQgdXNlcl9pZCA9IEBhbGljZTptYXRyaXguaW1hZ28ubG9jYWwKMDAxNmNpZCB0eXBlID0gYWNjZXNzCjAwMjFjaWQgbm9uY2UgPSBjcX4jazVTUDNeUlk2WnRECjAwMmZzaWduYXR1cmUg_K2biF-xm5ue7985RkAomVadF7yfy3UiEpH-e15m0esK", "events" => [%{"age" => 802, "content" => %{"is_direct" => true, "membership" => "invite"}, "event_id" => "$Z4mzNi1CtkGqKAvHc_VEkxeqJ1Nr-Yzr6_77hB0hBXw", "origin_server_ts" => 1610182036132, "room_id" => "!gvcurdLVxqoQvwaRom:kazarma.local", "sender" => "@muser90:kazarma.local", "state_key" => "@ap_pluser91=pleroma.local:kazarma.local", "type" => "m.room.member", "unsigned" => %{"age" => 802}, "user_id" => "@muser90:kazarma.local"}], "txn_id" => "93"}

  def new_event(%Event{
        type: "m.room.member",
        content: %{"membership" => "invite", "is_direct" => true},
        room_id: room_id,
        sender: _sender,
        state_key: "@ap_" <> _rest = user_id
      }) do
    Kazarma.ActivityPub.Activity.ChatMessage.accept_puppet_invitation(user_id, room_id)
    :ok
  end

  def new_event(%Event{
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: room_id,
        sender: _sender,
        state_key: "@ap_" <> _rest = user_id
      }) do
    # {:ok, actor} = Kazarma.ActivityPub.Actor.get_by_matrix_id(user_id)

    Kazarma.ActivityPub.Activity.Note.accept_puppet_invitation(user_id, room_id)
    :ok
  end

  def new_event(%Event{type: type} = event) do
    Logger.debug("Received #{type} from Synapse")
    Logger.debug(inspect(event))
  end

  defp is_tagged_message(%Event{content: %{"body" => body}}) do
    String.ends_with?(body, " \ufeff")
  end

  defp is_tagged_message(_), do: false
end
