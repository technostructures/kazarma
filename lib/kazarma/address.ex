defmodule Kazarma.Address do
  require Logger

  def ap_to_matrix(ap_id) do
    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<remote_domain>[a-z0-9\.-]+)/
    # Logger.debug(inspect(ap_id))

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
    regex = ~r/@(?<localpart>[a-z0-9_\.-=]+):(?<domain>[a-z0-9\.-]+)/
    sub_regex = ~r/ap_(?<localpart>[a-z0-9_\.-]+)=(?<domain>[a-z0-9\.-]+)/
    # Logger.error(inspect(matrix_id))
    
    {:ok, actor} =
      case Regex.named_captures(regex, matrix_id) do
        %{"localpart" => localpart, "domain" => domain} ->
          case Regex.named_captures(sub_regex, localpart) do
            %{"localpart" => sub_localpart, "domain" => sub_domain} ->
              ActivityPub.Actor.get_or_fetch_by_username("#{sub_localpart}@#{sub_domain}")
            nil ->
              ActivityPub.Actor.get_or_fetch_by_username("#{localpart}@#{domain}")
          end
      end

    actor.ap_id
  end

  def puppet_matrix_to_ap(_matrix_id) do
    # see in Kazarma.Matrix.User
    raise "no implemented"
  end
end
