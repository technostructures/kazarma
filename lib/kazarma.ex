# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma do
  @moduledoc """
  ![overview](assets/overview.png)
  """

  def search_user("http://" <> _ = address) do
    Kazarma.Address.get_actor(ap_id: address)
  end

  def search_user("https://" <> _ = address) do
    Kazarma.Address.get_actor(ap_id: address)
  end

  def search_user(username) do
    if String.match?(username, ~r/@[a-z0-9_.\-=]+:[a-z0-9\.-]+/) do
      Kazarma.Address.get_actor(matrix_id: username)
    else
      Kazarma.Address.get_actor(username: String.replace_prefix(username, "@", ""))
    end
  end
end
