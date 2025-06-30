# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.User do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.User`.
  """
  @behaviour MatrixAppService.Adapter.User
  require Logger

  @impl MatrixAppService.Adapter.User
  def query_user(matrix_id) do
    Logger.debug("Received ask for user #{matrix_id}")

    case Kazarma.Address.get_user_for_actor(matrix_id: matrix_id) do
      %{} ->
        :ok

      nil ->
        # Logger.error("Error getting user #{matrix_id} asked by homeserver: #{inspect(error)}")
        Logger.error("Error getting user #{matrix_id} asked by homeserver")
        :error
    end
  end
end
