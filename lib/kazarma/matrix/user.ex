defmodule Kazarma.Matrix.User do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.User`.
  """
  @behaviour MatrixAppService.Adapter.User
  require Logger

  @impl MatrixAppService.Adapter.User
  def query_user(user_id) do
    Logger.debug("Received ask for user #{user_id}")

    with {localpart, remote_domain} <-
           Kazarma.Address.parse_puppet_matrix_id(user_id),
         {:ok, _actor} <-
           ActivityPub.Actor.get_or_fetch_by_username("#{localpart}@#{remote_domain}"),
         {:ok, _matrix_id} <-
           Kazarma.Matrix.Client.register_puppet(localpart, remote_domain) do
      # :ok <- MatrixAppService.Client.set_displayname(...),
      # :ok <- MatrixAppService.Client.set_avatar_url(...),
      :ok
    else
      _ -> :error
    end
  end
end
