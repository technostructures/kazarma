# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Bridge do
  @moduledoc """
  Functions for the bridge database.
  """
  use MatrixAppService.BridgeConfig, repo: Kazarma.Repo
end
