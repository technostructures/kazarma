defmodule Kazarma.ActivityPub.Activity do
  @moduledoc """
  Functions in `ActivityPub.Adapter` dispatch handling of activities to more
  granular functions in this module.
  """
  use Kazarma.Config
  require Logger
  alias ActivityPub.Object
  alias Kazarma.Address
  alias MatrixAppService.Bridge.Room

  defmodule Utils do
    @moduledoc false
    use Kazarma.Config

    def send_message(room_id, from_id, body) do
      @matrix_client.send_message(room_id, {body <> " \ufeff", body <> " \ufeff"},
        user_id: from_id
      )
    end

    def insert_chat_message_bridge_room(room_id, from_ap_id) do
      Kazarma.Matrix.Bridge.create_room(%{
        local_id: room_id,
        data: %{type: :chat_message, to_ap: from_ap_id}
      })
    end

    def insert_note_bridge_room(room_id, conversation, participants) do
      Kazarma.Matrix.Bridge.create_room(%{
        local_id: room_id,
        remote_id: conversation,
        data: %{type: :note, to: participants}
      })
    end

    def get_or_create_direct_room(from_ap_id, to_ap_id) do
      from_matrix_id = Address.ap_to_matrix(from_ap_id)
      to_matrix_id = Address.ap_to_matrix(to_ap_id)
      # Logger.debug("from " <> inspect(from_matrix_id) <> " to " <> inspect(to_matrix_id))

      with {:error, :not_found} <-
             get_direct_room(from_matrix_id, to_matrix_id),
           {:ok, %{"room_id" => room_id}} <-
             create_direct_room(from_matrix_id, to_matrix_id),
           {:ok, _} <- insert_chat_message_bridge_room(room_id, from_ap_id) do
        {:ok, room_id}
      else
        {:ok, room_id} -> {:ok, room_id}
        {:error, error} -> {:error, error}
      end
    end

    def create_direct_room(from_matrix_id, to_matrix_id) do
      @matrix_client.create_room(
        [
          visibility: :private,
          name: nil,
          topic: nil,
          is_direct: true,
          invite: [to_matrix_id],
          room_version: "5"
        ],
        user_id: from_matrix_id
      )

      # |> IO.inspect()
    end

    def create_conversation(creator, invites) do
      @matrix_client.create_room(
        [
          visibility: :private,
          name: nil,
          topic: nil,
          is_direct: false,
          invite: invites,
          room_version: "5"
        ],
        user_id: creator
      )
    end

    def get_direct_rooms(matrix_id) do
      @matrix_client.get_data(
        @matrix_client.client(user_id: matrix_id),
        matrix_id,
        "m.direct"
      )

      # |> IO.inspect()
    end

    def get_direct_room(from_matrix_id, to_matrix_id) do
      with {:ok, data} <-
             get_direct_rooms(to_matrix_id),
           %{^from_matrix_id => rooms} when is_list(rooms) <- data do
        {:ok, List.last(rooms)}
      else
        {:error, 404, _error} ->
          # receiver has no "m.direct" account data set
          {:error, :not_found}

        data when is_map(data) ->
          # receiver has "m.direct" acount data set but not for sender
          {:error, :not_found}
      end
    end

    def get_or_create_conversation(conversation, creator, invites) do
      with nil <- Kazarma.Matrix.Bridge.get_room_by_remote_id(conversation),
           {:ok, %{"room_id" => room_id}} <-
             create_conversation(creator, invites),
           {:ok, _} <-
             insert_note_bridge_room(room_id, conversation, [creator | invites]) do
        {:ok, room_id}
      else
        %Room{local_id: local_id} -> {:ok, local_id}
        # {:ok, room_id} -> {:ok, room_id}
        {:error, error} -> {:error, error}
        _ -> {:error, :unknown_error}
      end
    end
  end

  def forward_chat_message(%{
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
    with {:ok, room_id} <-
           Utils.get_or_create_direct_room(from_id, to_id),
         {:ok, _} <-
           Utils.send_message(room_id, Address.ap_to_matrix(from_id), body) do
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def forward_note(%{
        data: %{"to" => to},
        object: %Object{
          data: %{
            "source" => source,
            "actor" => from,
            "conversation" => conversation
          }
        }
      }) do
    from = Address.ap_to_matrix(from)
    to = Enum.map(to, &Address.ap_to_matrix/1)

    with {:ok, room_id} <-
           Utils.get_or_create_conversation(conversation, from, to),
         {:ok, _} <-
           Utils.send_message(room_id, from, source) do
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end
end
