# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.User do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.User`.
  """
  @behaviour MatrixAppService.Adapter.User
  alias Kazarma.Logger

  @impl MatrixAppService.Adapter.User
  def query_user(user_id) do
    Logger.debug("Received ask for user #{user_id}")

    case Kazarma.Address.matrix_id_to_actor(user_id, [:activity_pub]) do
      {:ok, _actor} ->
        :ok

      error ->
        Logger.error("Error getting user #{user_id} asked by homeserver: #{inspect(error)}")
        :error
    end
  end
end
