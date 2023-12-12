# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.ServerBehaviour do
  @moduledoc """
  Behaviour used to mock the `ActivityPub` module.
  """

  @callback create(map()) :: {:ok, any()} | {:error, any()}
  @callback update(map()) :: {:ok, any()} | {:error, any()}
  @callback follow(map()) :: {:ok, any()} | {:error, any()}
  @callback unfollow(map()) :: {:ok, any()} | {:error, any()}
  @callback delete(map(), bool, map()) :: {:ok, any()} | {:error, any()}
  @callback accept(map()) :: {:ok, any()} | {:error, any()}
end
