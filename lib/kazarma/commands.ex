# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Commands do
  @moduledoc """
  Appservice bot commands.
  """
  alias Kazarma.Address
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Room

  def handle_command(command, room_id, user_id) when is_binary(command) do
    String.split(command, ~r{\s}, trim: true)
    |> handle_command(room_id, user_id)
  end

  def handle_command(["outbox"], room_id, user_id) do
    case Bridge.get_room_by_local_id(room_id) do
      %Room{data: %{"type" => "matrix_outbox"}} = room ->
        Kazarma.RoomType.MatrixOutbox.maybe_set_outbox_type(room_id, user_id)

      nil ->
        {:error, :room_type_should_be_matrix_user_room, room_id}
    end
  end

  def handle_command(["follow"], room_id, user_id) do
    with %Room{data: %{"type" => "actor_outbox", "matrix_id" => receiver_id}} <-
           Bridge.get_room_by_local_id(room_id),
         {:ok, sender} <- Address.matrix_id_to_actor(user_id),
         {:ok, receiver} <- Address.matrix_id_to_actor(receiver_id) do
      Kazarma.ActivityPub.follow(sender, receiver)
    else
      nil ->
        {:error, :room_type_should_be_ap_user_room, room_id}

      {:error, error} ->
        {:error, error}
    end
  end

  def handle_command(["unfollow"], room_id, user_id) do
    with %Room{data: %{"type" => "actor_outbox", "matrix_id" => receiver_id}} <-
           Bridge.get_room_by_local_id(room_id),
         {:ok, sender} <- Address.matrix_id_to_actor(user_id),
         {:ok, receiver} <- Address.matrix_id_to_actor(receiver_id) do
      Kazarma.ActivityPub.unfollow(sender, receiver)
    else
      nil ->
        {:error, :room_type_should_be_ap_user_room, room_id}

      {:error, error} ->
        {:error, error}
    end
  end
end
