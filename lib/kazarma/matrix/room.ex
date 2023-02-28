# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Room do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.Room`.
  """
  @behaviour MatrixAppService.Adapter.Room
  alias Kazarma.Logger

  @impl MatrixAppService.Adapter.Room
  def query_alias(room_alias) do
    Logger.debug("Received ask for outbox #{room_alias}")

    :error
  end
end
