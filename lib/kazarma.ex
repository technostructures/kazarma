defmodule Kazarma do
  @moduledoc """
  ![overview](assets/overview.png)
  """

  def search_user("http" <> _ = address) do
    ActivityPub.Actor.get_or_fetch_by_ap_id(address)
  end

  def search_user(username) do
    cond do
      String.match?(username, ~r/@[a-z0-9_.\-=]+:[a-z0-9\.-]+/) ->
        Kazarma.Address.matrix_id_to_actor(username)

      true ->
        ActivityPub.Actor.get_or_fetch_by_username(username)
    end
  end
end
