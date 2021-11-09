# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Config do
  @moduledoc """
  Helpers for managing project-wide configuration.
  """
  defmacro __using__(_) do
    quote do
      @matrix_client Application.get_env(:kazarma, :matrix) |> Keyword.fetch!(:client)
      @activitypub_server Application.get_env(:kazarma, :activity_pub) |> Keyword.fetch!(:server)
    end
  end
end
