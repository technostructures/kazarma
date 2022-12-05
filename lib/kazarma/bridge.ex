# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Bridge do
  @moduledoc """
  Functions for the bridge database.
  """
  use MatrixAppService.BridgeConfig, repo: Kazarma.Repo
end
