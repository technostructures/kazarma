# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Client do
  @moduledoc """
  Wrapper for MatrixAppService.Client.
  """
  use Kazarma.Config
  require Logger

  def register(username) do
    localpart =
      username
      |> String.replace_suffix(":#{Kazarma.Address.domain()}", "")
      |> String.replace_leading("@", "")

    @matrix_client.register(
      username: localpart,
      device_id: "KAZARMA_APP_SERVICE",
      initial_device_display_name: "Kazarma",
      registration_type: "m.login.application_service"
    )
  end

  def register_puppet(localpart, remote_domain) do
    register("#{Kazarma.Address.puppet_prefix()}#{localpart}=#{remote_domain}")
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
  end

  def put_displayname(matrix_id, displayname) do
    @matrix_client.put_displayname(
      @matrix_client.client(user_id: matrix_id),
      matrix_id,
      displayname
    )
  end

  def put_avatar_url(matrix_id, avatar_url) do
    @matrix_client.put_avatar_url(
      @matrix_client.client(user_id: matrix_id),
      matrix_id,
      avatar_url
    )
  end

  def upload_and_set_avatar(matrix_id, avatar_url) do
    with {:ok, image_bin} <- download_file(avatar_url),
         filename = Path.basename(avatar_url),
         mimetype = MIME.from_path(filename),
         {:ok, matrix_url} <-
           @matrix_client.upload(
             @matrix_client.client(user_id: matrix_id),
             image_bin,
             filename: filename,
             mimetype: mimetype
           ),
         :ok <- put_avatar_url(matrix_id, matrix_url) do
      :ok
    end
  end

  def create_attachment_message(matrix_id, file_bin, opts) do
    @matrix_client.create_attachment_message(
      @matrix_client.client(user_id: matrix_id),
      {:data, file_bin, Keyword.fetch!(opts, :filename)},
      opts
    )
  end

  def send_attachment_message(matrix_id, room_id, file_bin, opts) do
    with {:ok, msg} <- create_attachment_message(matrix_id, file_bin, opts) do
      send_message(room_id, matrix_id, msg)
    end
  end

  def send_attachment_message_for_ap_data(%{mimetype: mimetype, url: url}, matrix_id, room_id) do
    filename = Path.basename(url)

    opts =
      [
        body: filename,
        filename: filename,
        mimetype: mimetype,
        msgtype: msgtype_for_mimetype(mimetype)
      ]
      |> Enum.filter(fn {_, v} -> v != nil end)

    with {:ok, file_bin} <- download_file(url) do
      send_attachment_message(matrix_id, room_id, file_bin, opts)
    end
  end

  def get_direct_room(from_matrix_id, to_matrix_id) do
    with {:ok, data} <-
           get_direct_rooms(from_matrix_id),
         %{^to_matrix_id => rooms} when is_list(rooms) <- data do
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
    with {:ok, %{"room_id" => room_id}} <-
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
           ) do
      put_new_direct_room_data(from_matrix_id, to_matrix_id, room_id)

      {:ok, %{"room_id" => room_id}}
    else
      error -> error
    end
  end

  def put_new_direct_room_data(from_matrix_id, to_matrix_id, room_id) do
    data =
      case @matrix_client.get_data(
             @matrix_client.client(user_id: from_matrix_id),
             from_matrix_id,
             "m.direct"
           ) do
        {:ok, data} -> data
        _ -> %{}
      end

    new_data =
      Map.update(data, to_matrix_id, [room_id], fn room_list ->
        [room_id | room_list]
      end)

    @matrix_client.put_data(
      @matrix_client.client(user_id: from_matrix_id),
      from_matrix_id,
      "m.direct",
      new_data
    )
  end

  def create_multiuser_room(creator, invites, opts \\ []) do
    opts =
      [
        visibility: :private,
        name: nil,
        topic: nil,
        is_direct: false,
        invite: invites,
        room_version: "5"
      ]
      |> Keyword.merge(opts)

    @matrix_client.create_room(
      opts,
      user_id: creator
    )
  end

  def send_tagged_message(_room_id, _from_id, nil), do: {:ok, :empty_message_not_sent}

  def send_tagged_message(room_id, from_id, body) do
    @matrix_client.send_message(room_id, {body <> " \ufeff", body <> " \ufeff"}, user_id: from_id)
  end

  def send_message(room_id, from_id, msg) do
    @matrix_client.send_message(room_id, msg, user_id: from_id)
  end

  def get_media_url("mxc://" <> matrix_url) do
    [server_name, media_id] = String.split(matrix_url, "/", parts: 2)

    @matrix_client.client().base_url
    |> URI.merge("/_matrix/media/r0/download/" <> server_name <> "/" <> media_id)
    |> URI.to_string()
  end

  def get_media_url(nil), do: nil

  defp msgtype_for_mimetype("image" <> _), do: "m.image"
  defp msgtype_for_mimetype("audio" <> _), do: "m.audio"
  defp msgtype_for_mimetype("location" <> _), do: "m.location"
  defp msgtype_for_mimetype("video" <> _), do: "m.video"
  defp msgtype_for_mimetype(_), do: "m.file"

  defp download_file(url) do
    case ActivityPub.HTTP.get(url) do
      {:ok, %Tesla.Env{body: file_bin}} -> {:ok, file_bin}
      error -> error
    end
  end
end
