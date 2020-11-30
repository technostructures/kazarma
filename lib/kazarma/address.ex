defmodule Kazarma.Address do
  def ap_to_matrix(ap_id) do
    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<remote_domain>[a-z0-9\.-]+)/

    with {:ok, %ActivityPub.Actor{username: username}} <-
           ActivityPub.Actor.get_cached_by_ap_id(ap_id),
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
  end
end
