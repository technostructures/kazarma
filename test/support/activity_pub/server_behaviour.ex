# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.ServerBehaviour do
  @moduledoc """
  Behaviour used to mock the `ActivityPub` module.
  """

  @callback create(map(), String.t() | nil) :: {:ok, any()} | {:error, any()}
  @callback update(map()) :: {:ok, any()} | {:error, any()}
end
