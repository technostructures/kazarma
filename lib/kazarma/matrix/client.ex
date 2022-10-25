# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
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
      initial_device_display_name: "Kazarma",
      registration_type: "m.login.application_service"
    )
  end

  def register_puppet(localpart, remote_domain) do
    register("#{Kazarma.Address.puppet_prefix()}#{localpart}___#{remote_domain}")
  end

  def join(user_id, room_id) do
    @matrix_client.join(room_id, user_id: user_id)
  end

  def get_profile(matrix_id) do
    @matrix_client.get_profile(matrix_id)
  end

  def get_direct_rooms(matrix_id) do
    @matrix_client.get_data(
      matrix_id,
      "m.direct",
      user_id: matrix_id
    )
  end

  def redact_message(from_matrix_id, room_id, event_id, reason \\ nil) do
    @matrix_client.redact_message(
      room_id,
      event_id,
      reason,
      user_id: from_matrix_id
    )
  end

  def put_displayname(matrix_id, displayname) do
    @matrix_client.put_displayname(
      matrix_id,
      displayname,
      user_id: matrix_id
    )
  end

  def put_avatar_url(matrix_id, avatar_url) do
    @matrix_client.put_avatar_url(
      matrix_id,
      avatar_url,
      user_id: matrix_id
    )
  end

  def upload_media(matrix_id, url) do
    {:ok, %Tesla.Env{body: image_bin}} = ActivityPub.HTTP.get(url)
    filename = Path.basename(url)
    mimetype = MIME.from_path(filename)

    @matrix_client.upload(
      image_bin,
      [filename: filename, mimetype: mimetype],
      user_id: matrix_id
    )
  end

  def upload_and_set_avatar(matrix_id, avatar_url) do
    {:ok, matrix_url} = upload_media(matrix_id, avatar_url)
    :ok = put_avatar_url(matrix_id, matrix_url)
    :ok
  end

  def create_attachment_message(matrix_id, file_bin, opts) do
    @matrix_client.create_attachment_message(
      {:data, file_bin, Keyword.fetch!(opts, :filename)},
      opts,
      user_id: matrix_id
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
    case @matrix_client.create_room(
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
      {:ok, %{"room_id" => room_id}} ->
        put_new_direct_room_data(from_matrix_id, to_matrix_id, room_id)

        {:ok, %{"room_id" => room_id}}

      error ->
        error
    end
  end

  def put_new_direct_room_data(from_matrix_id, to_matrix_id, room_id) do
    data =
      case @matrix_client.get_data(
             from_matrix_id,
             "m.direct",
             user_id: from_matrix_id
           ) do
        {:ok, data} -> data
        _ -> %{}
      end

    new_data =
      Map.update(data, to_matrix_id, [room_id], fn room_list ->
        [room_id | room_list]
      end)

    @matrix_client.put_data(
      from_matrix_id,
      "m.direct",
      new_data,
      user_id: from_matrix_id
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

  def create_outbox_room(
        creator,
        invites,
        name \\ nil,
        room_alias_name \\ nil
      ) do
    @matrix_client.create_room(
      [
        visibility: :public,
        name: name,
        topic: nil,
        is_direct: false,
        invite: invites,
        room_version: "5",
        room_alias_name: room_alias_name,
        # power_level_content_override: %{},
        initial_state: [%{type: "m.room.guest_access", content: %{guest_access: :can_join}}]
      ],
      user_id: creator
    )
  end

  def send_tagged_message(_room_id, _from_id, nil),
    do: {:error, :empty_message_not_sent}

  def send_tagged_message(_room_id, _from_id, {nil, _}),
    do: {:error, :empty_message_not_sent}

  def send_tagged_message(_room_id, _from_id, %{"body" => nil}),
    do: {:error, :empty_message_not_sent}

  def send_tagged_message(room_id, from_id, body) do
    @matrix_client.send_message(room_id, tag_message(body), user_id: from_id)
  end

  def tag_message({body, formatted_body}), do: {body <> " \ufeff", formatted_body}
  def tag_message(%{"body" => body} = event), do: Map.put(event, "body", body <> " \ufeff")
  def tag_message(message), do: {message <> " \ufeff", message}

  def send_message(room_id, from_id, msg) do
    @matrix_client.send_message(room_id, msg, user_id: from_id)
  end

  def get_media_url(nil), do: nil

  def get_media_url("mxc://" <> matrix_url) do
    [server_name, media_id] = String.split(matrix_url, "/", parts: 2)

    @matrix_client.client().base_url
    |> URI.merge("/_matrix/media/r0/download/" <> server_name <> "/" <> media_id)
    |> URI.to_string()
  end

  def get_alias(alias), do: @matrix_client.get_alias(alias)

  def reply_event(reply_to, body, formatted_body) do
    %{
      "msgtype" => "m.text",
      "body" => body,
      "formatted_body" => formatted_body,
      "m.relates_to" => %{
        "m.in_reply_to" => %{
          "event_id" => reply_to
        }
      }
    }
  end

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
