# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma do
  @moduledoc """
  ![overview](assets/overview.png)
  """

  def search_user("http://" <> _ = address) do
    ActivityPub.Actor.get_or_fetch_by_ap_id(address)
  end

  def search_user("https://" <> _ = address) do
    ActivityPub.Actor.get_or_fetch_by_ap_id(address)
  end

  def search_user(username) do
    if String.match?(username, ~r/@[a-z0-9_.\-=]+:[a-z0-9\.-]+/) do
      Kazarma.Address.matrix_id_to_actor(username)
    else
      String.replace_prefix(username, "@", "")
      |> ActivityPub.Actor.get_or_fetch_by_username()
    end
  end
end
