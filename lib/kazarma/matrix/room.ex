# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Room do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.Room`.
  """
  @behaviour MatrixAppService.Adapter.Room
  alias Kazarma.Address
  alias Kazarma.Logger

  @impl MatrixAppService.Adapter.Room
  def query_alias(room_alias) do
    Logger.debug("Received ask for outbox #{room_alias}")

    with true <- String.starts_with?(room_alias, "#" <> Address.puppet_prefix()),
         user_id = String.replace_leading(room_alias, "#", "@"),
         {:ok, actor} <-
           Address.matrix_id_to_actor(user_id, [
             :activity_pub
           ]),
         # @TODO: configure timeline bridging (from AP network) enabled
         {:ok, _} <- Kazarma.RoomType.Actor.get_or_create_outbox(actor, user_id) do
      :ok
    else
      false ->
        Logger.warn("Received appservice request for unhandled alias")
        :error

      e ->
        Logger.error("Failed to create timeline room")
        Logger.debug(inspect(e))
        :error
    end
  end
end
