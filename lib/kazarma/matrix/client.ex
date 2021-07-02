defmodule Kazarma.Matrix.Client do
  @moduledoc """
  Wrapper for MatrixAppService.Client.
  """
  use Kazarma.Config

  def register(username) do
    localpart =
      username
      |> String.replace_suffix(":#{Kazarma.Address.domain()}", "")
      |> String.replace_leading("@", "")

    @matrix_client.register(
      username: localpart,
      device_id: "KAZARMA_APP_SERVICE",
      initial_device_display_name: "Kazarma"
    )
  end

  def register_puppet(localpart, remote_domain) do
    register("ap_#{localpart}=#{remote_domain}")
  end

  def join(user_id, room_id) do
    @matrix_client.join(@matrix_client.client(user_id: user_id), room_id)
  end

  def get_profile(matrix_id) do
    @matrix_client.get_profile(@matrix_client.client(), matrix_id)
  end

  def get_direct_rooms(matrix_id) do
    @matrix_client.get_data(
      @matrix_client.client(user_id: matrix_id),
      matrix_id,
      "m.direct"
    )

    # |> IO.inspect()
  end

  def set_displayname(matrix_id, name) do
    @matrix_client.put_displayname(
      @matrix_client.client(user_id: matrix_id),
      matrix_id,
      name
    )
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

  def create_multiuser_room(creator, invites) do
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

  def send_tagged_message(room_id, from_id, body) do
    @matrix_client.send_message(room_id, {body <> " \ufeff", body <> " \ufeff"}, user_id: from_id)
  end

  def get_media_url("mxc://" <> matrix_url) do
    [server_name, media_id] = String.split(matrix_url, "/", parts: 2)

    @matrix_client.client().base_url
    |> URI.merge("/_matrix/media/r0/download/" <> server_name <> "/" <> media_id)
    |> URI.to_string()
  end
end
