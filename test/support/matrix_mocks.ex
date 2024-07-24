# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.MatrixMocks do
  @moduledoc false

  require Kazarma.Mocks
  import Kazarma.Mocks

  def expect_client(client) do
    client
    |> expect(:client, fn ->
      %{base_url: "http://matrix"}
    end)
  end

  def expect_get_profile(client, matrix_id, profile) do
    client
    |> expect(:get_profile, fn
      ^matrix_id ->
        {:ok, profile}
    end)
  end

  def expect_get_profile_not_found(client, matrix_id) do
    client
    |> expect(:get_profile, fn
      ^matrix_id ->
        {:error, :not_found}
    end)
  end

  def expect_join(client, matrix_id, room_id) do
    client
    |> expect(:join, fn
      ^room_id, user_id: ^matrix_id ->
        :ok
    end)
  end

  def expect_get_data(client, matrix_id, key, data) do
    client
    |> expect(:get_data, fn
      ^matrix_id, ^key, user_id: ^matrix_id ->
        {:ok, data}
    end)
  end

  def expect_put_data(client, matrix_id, key, data) do
    client
    |> expect(:put_data, fn
      ^matrix_id, ^key, ^data, user_id: ^matrix_id ->
        :ok
    end)
  end

  def expect_upload_something(client, matrix_id, mxc_url) do
    client
    |> expect(:upload, fn _blob, _opts, user_id: ^matrix_id ->
      {:ok, mxc_url}
    end)
  end

  def expect_upload(client, matrix_id, blob, opts, mxc_url) do
    client
    |> expect(:upload, fn ^blob, ^opts, user_id: ^matrix_id ->
      {:ok, mxc_url}
    end)
  end

  def expect_put_avatar_url(client, matrix_id, mxc_url) do
    client
    |> expect(:put_avatar_url, fn ^matrix_id, ^mxc_url, user_id: ^matrix_id ->
      :ok
    end)
  end

  def expect_put_displayname(client, matrix_id, displayname) do
    client
    |> expect(:put_displayname, fn ^matrix_id, ^displayname, user_id: ^matrix_id ->
      :ok
    end)
  end

  def expect_send_message(client, matrix_id, room_id, content, event_id) do
    client
    |> expect(:send_message, fn ^room_id, ^content, [user_id: ^matrix_id] ->
      {:ok, event_id}
    end)
  end

  def expect_send_state_event(
        client,
        matrix_id,
        room_id,
        event_type,
        state_key,
        content,
        event_id
      ) do
    client
    |> expect(:send_state_event, fn ^room_id,
                                    ^event_type,
                                    ^state_key,
                                    ^content,
                                    [user_id: ^matrix_id] ->
      {:ok, event_id}
    end)
  end

  def expect_get_state(client, matrix_id, room_id, event_type, state_key, data) do
    client
    |> expect(:get_state, fn ^room_id, ^event_type, ^state_key, user_id: ^matrix_id ->
      data
    end)
  end

  def expect_get_state_as(client, room_id, event_type, state_key, data) do
    client
    |> expect(:get_state, fn ^room_id, ^event_type, ^state_key ->
      {:ok, data}
    end)
  end

  def expect_redact_message(client, matrix_id, room_id, event_id, redact_event_id) do
    client
    |> expect(:redact_message, fn ^room_id, ^event_id, nil, user_id: ^matrix_id ->
      {:ok, redact_event_id}
    end)
  end

  def expect_create_room(client, matrix_id, params, room_id) do
    client
    |> expect(:create_room, fn ^params, user_id: ^matrix_id ->
      {:ok, %{"room_id" => room_id}}
    end)
  end

  def expect_create_room_existing(client, matrix_id, params) do
    client
    |> expect(:create_room, fn ^params, user_id: ^matrix_id ->
      {:error, 400, %{"errcode" => "M_ROOM_IN_USE"}}
    end)
  end

  def expect_get_alias(client, alias, room_id) do
    client
    |> expect(:get_alias, fn ^alias ->
      {:ok, {room_id, nil}}
    end)
  end

  def expect_register(client, %{
        username: username,
        matrix_id: matrix_id,
        displayname: displayname
      }) do
    client
    |> expect(:register, 1, fn
      [
        username: ^username,
        device_id: "KAZARMA_APP_SERVICE",
        initial_device_display_name: "Kazarma",
        registration_type: "m.login.application_service"
      ] ->
        {:ok, %{"user_id" => matrix_id}}
    end)
    |> expect_put_displayname(matrix_id, displayname)
  end
end
