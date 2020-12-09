defmodule Kazarma.Address do
  require Logger

  alias KazarmaWeb.Router.Helpers, as: Routes
  alias KazarmaWeb.Endpoint

  def ap_to_matrix(ap_id) do
    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<remote_domain>[a-z0-9\.-]+)/

    with {:ok, %ActivityPub.Actor{username: username}} <-
           ActivityPub.Actor.get_cached_by_ap_id(ap_id),
         # _ <- Logger.error(ap_id),
         # _ <- Logger.error(actor),
         %{"localpart" => localpart, "remote_domain" => remote_domain} <-
           Regex.named_captures(regex, username) do
      if remote_domain == ActivityPub.domain() do
        "@#{localpart}:#{ActivityPub.domain()}"
      else
        "@ap_#{localpart}=#{remote_domain}:#{ActivityPub.domain()}"
      end
    end
  end

  def matrix_to_ap(matrix_id) do
    regex = ~r/@(?<localpart>[a-z0-9_\.-]+):(?<domain>[a-z0-9\.-]+)/

    with %{"localpart" => localpart} <-
      # TODO should also handle remote matrix users
      # 
      Regex.named_captures(regex, matrix_id) do
        Routes.activity_pub_url(Endpoint, :actor, localpart)
      end
  end

  def puppet_matrix_to_ap(_matrix_id) do
    raise "no implemented" # see in Kazarma.Matrix.User
  end
end
