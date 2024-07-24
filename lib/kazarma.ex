# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma do
  @moduledoc """
  ![overview](assets/overview.png)
  """

  def search_user("http://" <> _ = address) do
    ActivityPub.Actor.get_cached_or_fetch(ap_id: address)
  end

  def search_user("https://" <> _ = address) do
    ActivityPub.Actor.get_cached_or_fetch(ap_id: address)
  end

  def search_user(username) do
    if String.match?(username, ~r/@[a-z0-9_.\-=]+:[a-z0-9\.-]+/) do
      Kazarma.Address.matrix_id_to_actor(username)
    else
      ActivityPub.Actor.get_cached_or_fetch(username: String.replace_prefix(username, "@", ""))
    end
  end
end
