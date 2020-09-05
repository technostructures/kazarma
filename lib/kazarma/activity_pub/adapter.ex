defmodule Kazarma.ActivityPub.Adapter do
  require Logger
  @behaviour ActivityPub.Adapter

  @impl ActivityPub.Adapter
  def get_actor_by_username(username) do
    Logger.info("asked for local Matrix user #{username}")
    {:error, :not_found}
  end
end
