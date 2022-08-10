# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Collection do
  @moduledoc """
  Handling of ActivityPub collections.
  """

  def get_or_create_outbox({:matrix_id, matrix_id}) do
    with {:ok, actor} <-
           Kazarma.Address.matrix_id_to_actor(matrix_id, [
             :activity_pub,
             :local_matrix,
             :remote_matrix
           ]) do
      get_or_create_outbox(actor, matrix_id)
    end
  end

  def get_or_create_outbox({:ap_id, ap_id}) do
    with {:ok, %ActivityPub.Actor{username: username} = actor} <-
           ActivityPub.Actor.get_cached_by_ap_id(ap_id),
         {:ok, matrix_id} <-
           Kazarma.Address.ap_username_to_matrix_id(username, [
             :activity_pub,
             :local_matrix,
             :remote_matrix
           ]) do
      get_or_create_outbox(actor, matrix_id)
    end
  end

  def get_or_create_outbox(
        %ActivityPub.Actor{ap_id: ap_id, data: %{"name" => name}} = actor,
        matrix_id
      ) do
    alias = Kazarma.Address.get_matrix_id_localpart(matrix_id)

    with nil <- Kazarma.Matrix.Bridge.get_room_by_remote_id(ap_id),
         {:ok, %{"room_id" => room_id}} <-
           Kazarma.Matrix.Client.create_outbox_room(
             matrix_id,
             [],
             name,
             alias
           ),
         {:ok, room} <- Kazarma.Matrix.Bridge.insert_outbox_room(room_id, actor.ap_id, matrix_id) do
      {:ok, room}
    else
      {:error, 400, %{"errcode" => "M_ROOM_IN_USE"}} ->
        {:ok, {room_id, _}} =
          Kazarma.Matrix.Client.get_alias("##{alias}:#{Kazarma.Address.domain()}")

        Kazarma.Matrix.Bridge.insert_outbox_room(
          room_id,
          actor.ap_id,
          matrix_id
        )

      %MatrixAppService.Bridge.Room{} = room ->
        {:ok, room}
    end
  end
end
