defmodule Kazarma.RoomType.Collection do
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Matrix.Client
  alias Kazarma.ActivityPub.Activity
  alias Kazarma.Matrix.Bridge
  alias MatrixAppService.Bridge.Room

  def create_from_ap(%{
        data: %{"actor" => from},
        object: %Object{
          data:
            %{
              "id" => object_id,
              "attributedTo" => group_ap_id,
              "to" => [group_members]
            } = object_data
        }
      }) do
    Logger.debug("Received private Note activity (Mobilizon style)")

    with {:ok, matrix_id} <- Address.ap_id_to_matrix(from),
         {:ok, %{username: group_username, data: %{"name" => group_name}}} <-
           ActivityPub.Actor.get_cached_by_ap_id(group_ap_id),
         {:ok, group_matrix_id} <- Address.ap_username_to_matrix_id(group_username),
         {:ok, room_id} <-
           get_or_create_collection_room(group_members, group_matrix_id, group_name),
         :ok <- Client.invite_and_accept(room_id, group_matrix_id, matrix_id),
         attachments = Map.get(object_data, "attachment"),
         {:ok, event_id} <-
           Activity.send_message_and_attachment(matrix_id, room_id, object_data, attachments),
         {:ok, _} <-
           Bridge.create_event(%{
             local_id: event_id,
             remote_id: object_id,
             room_id: room_id
           }) do
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def get_or_create_collection_room(members_ap_id, matrix_id, name) do
    with nil <- Bridge.get_room_by_remote_id(members_ap_id),
         {:ok, %{"room_id" => room_id}} <-
           Client.create_multiuser_room(matrix_id, [], name: name),
         {:ok, _} <-
           Bridge.insert_collection_bridge_room(room_id, members_ap_id) do
      {:ok, room_id}
    else
      %Room{local_id: local_id} -> {:ok, local_id}
      {:error, error} -> {:error, error}
      _ -> {:error, :unknown_error}
    end
  end

  def create_from_matrix(
        event,
        %Room{data: %{"type" => "collection"}, remote_id: group_ap_id},
        content
      ) do
    with {:ok, sender_actor} <- Address.matrix_id_to_actor(event.sender),
         to = [group_ap_id],
         replied_activity = Activity.get_replied_activity_if_exists(event),
         context = Activity.make_context(replied_activity),
         in_reply_to = Activity.make_in_reply_to(replied_activity),
         attachment = Activity.attachment_from_matrix_event_content(event.content),
         tags = [],
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
