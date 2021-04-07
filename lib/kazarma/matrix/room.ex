# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Room do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.Room`.
  """
  @behaviour MatrixAppService.Adapter.Room
  require Logger

  @impl MatrixAppService.Adapter.Room
  def query_alias(room_alias) do
    Logger.debug("Received ask for alias #{room_alias}")
  end
end
