defmodule Kazarma.Matrix.User do
  require Logger

  def query_user(user_id) do
    Logger.debug("Received ask for user #{user_id}")

    domain = Application.fetch_env!(:activity_pub, :domain)
    regex = ~r/@ap_(?<localpart>[a-z0-9_\.-]+)=(?<remote_domain>[a-z0-9\.-]+):#{domain}/

    with %{"localpart" => localpart, "remote_domain" => remote_domain} <-
           Regex.named_captures(regex, user_id),
         username = "#{localpart}@#{remote_domain}",
         {:ok, _actor} <- ActivityPub.Actor.get_or_fetch_by_username(username) do
      # TODO: create corresponding Matrix user
      :ok
    else
      _ -> :error
    end
  end
end
