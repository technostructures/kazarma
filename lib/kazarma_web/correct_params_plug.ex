# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.CorrectParamsPlug do
  @moduledoc """
  Instead of modifying controllers in the ActivityPub library,
  we generate :usersame from :server and :localpart
  """

  @behaviour Plug

  @impl Plug
  def init(_), do: nil

  @impl Plug
  def call(%{params: %{"localpart" => localpart, "server" => "-"} = params} = conn, _action) do
    new_params = Map.put(params, "username", "#{localpart}@#{Kazarma.Address.domain()}")

    %{conn | params: new_params}
  end

  def call(%{params: %{"localpart" => localpart, "server" => server} = params} = conn, _action) do
    new_params = Map.put(params, "username", "#{localpart}@#{server}")

    %{conn | params: new_params}
  end
end
