defmodule Kazarma.RoomType.Actor do
  alias ActivityPub.Object
  alias Kazarma.ActivityPub.Collection
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias MatrixAppService.Bridge.Room

  def create_from_ap(
        %{
          object: %Object{
            data:
              %{
                "id" => object_id,
                "actor" => from_id
              } = object_data
          }
        } = _activity
      ) do
    Logger.debug("Received public Note activity")

    with {:ok, from_matrix_id} <- Address.ap_id_to_matrix(from_id),
         %MatrixAppService.Bridge.Room{local_id: room_id} <-
           get_room_for_public_create(object_data),
         Client.join(from_matrix_id, room_id),
         attachments = Map.get(object_data, "attachment"),
         {:ok, event_id} <-
           Activity.send_message_and_attachment(from_matrix_id, room_id, object_data, attachments),
         {:ok, _} <-
           Bridge.create_event(%{
             local_id: event_id,
             remote_id: object_id,
             room_id: room_id
           }) do
      :ok
    end
  end

  defp get_room_for_public_create(%{"inReplyTo" => reply_to_ap_id} = object_data) do
    case Bridge.get_events_by_remote_id(reply_to_ap_id) do
      [%BridgeEvent{room_id: replied_to_room_id} | _] ->
        case Bridge.get_room_by_local_id(replied_to_room_id) do
          %Room{data: %{"type" => "outbox"}} = room -> room
          _ -> get_room_for_public_create(Map.delete(object_data, "inReplyTo"))
        end

      _ ->
        get_room_for_public_create(Map.delete(object_data, "inReplyTo"))
    end
  end

  defp get_room_for_public_create(%{"actor" => from_id}) do
    case Collection.get_or_create_outbox({:ap_id, from_id}) do
      {:ok, room} ->
        room

      _ ->
        nil
    end
  end

  def create_from_matrix(event, %Room{data: %{"type" => "outbox"}} = room, content) do
    with {:ok, sender_actor} <- Address.matrix_id_to_actor(event.sender),
         {:ok, receiver_actor} <- Address.matrix_id_to_actor(room.data["matrix_id"]),
         to = ["https://www.w3.org/ns/activitystreams#Public", receiver_actor.ap_id],
         replied_activity = Activity.get_replied_activity_if_exists(event),
         context = Activity.make_context(replied_activity),
         in_reply_to = Activity.make_in_reply_to(replied_activity),
         attachment = Activity.attachment_from_matrix_event_content(event.content),
         tags = [
           %{
             "href" => receiver_actor.ap_id,
             "name" => "@#{receiver_actor.data["preferredUsername"]}",
             "type" => "Mention"
           }
         ],
         {:ok, %{object: %Object{data: %{"id" => remote_id}}}} <-
           Activity.create(
             type: "Note",
             sender: sender_actor,
             receivers_id: to,
             context: context,
             in_reply_to: in_reply_to,
             content: content,
             attachment: attachment,
             tags: tags
           ) do
      Bridge.create_event(%{
        local_id: event.event_id,
        remote_id: remote_id,
        room_id: event.room_id
      })

      :ok
    end
  end
end
