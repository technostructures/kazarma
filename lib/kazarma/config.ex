# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Config do
  @moduledoc """
  Helpers for managing project-wide configuration.
  """
  defmacro __using__(_) do
    quote do
      @matrix_client Application.compile_env!(:kazarma, [:matrix, :client])
      @activitypub_server Application.compile_env!(:kazarma, [:activity_pub, :server])
    end
  end
end
