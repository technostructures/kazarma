defmodule Kazarma.Matrix.User do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.User`.
  """
  @behaviour MatrixAppService.Adapter.User
  require Logger

  @impl MatrixAppService.Adapter.User
  def query_user(user_id) do
    Logger.debug("Received ask for user #{user_id}")

    domain = Application.fetch_env!(:activity_pub, :domain)
    regex = ~r/@ap_(?<localpart>[a-z0-9_\.-]+)=(?<remote_domain>[a-z0-9\.-]+):#{domain}/

    with %{"localpart" => localpart, "remote_domain" => remote_domain} <-
           Regex.named_captures(regex, user_id),
         username = "#{localpart}@#{remote_domain}",
         {:ok, _actor} <- ActivityPub.Actor.get_or_fetch_by_username(username),
         {:ok, _matrix_id} <-
           MatrixAppService.Client.register(
             username: "ap_#{localpart}=#{remote_domain}",
             device_id: "KAZARMA_APP_SERVICE",
             initial_device_display_name: "Kazarma"
           ) do
      # :ok <- MatrixAppService.Client.set_displayname(...),
      # :ok <- MatrixAppService.Client.set_avatar_url(...),
      :ok
    else
      _ -> :error
    end
  end
end
