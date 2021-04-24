defmodule Kazarma.Address do
  @moduledoc """
  Functions about Matrix and ActivityPub addresses conversion.
  """
  require Logger

  def parse_activitypub_username(username) do
    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<remote_domain>[a-z0-9\.-]+)/

    case Regex.named_captures(regex, username) do
      %{"localpart" => localpart, "remote_domain" => remote_domain} ->
        {localpart, remote_domain}

      _ ->
        nil
    end
  end

  def parse_puppet_matrix_id(user_id) do
    domain = Application.fetch_env!(:activity_pub, :domain)
    regex = ~r/@ap_(?<localpart>[a-z0-9_\.-]+)=(?<remote_domain>[a-z0-9\.-]+):#{domain}/

    case Regex.named_captures(regex, user_id) do
      %{"localpart" => localpart, "remote_domain" => remote_domain} ->
        {localpart, remote_domain}

      _ ->
        nil
    end
  end

  def parse_matrix_id(user_id) do
    regex = ~r/@(?<localpart>[a-z0-9_\.-=]+):(?<domain>[a-z0-9\.-]+)/
    sub_regex = ~r/ap_(?<localpart>[a-z0-9_\.-]+)=(?<domain>[a-z0-9\.-]+)/
    # Logger.error(inspect(user_id))

    domain = ActivityPub.domain()

    case Regex.named_captures(regex, user_id) do
      %{"localpart" => localpart, "domain" => ^domain} ->
        # local Matrix user
        case Regex.named_captures(sub_regex, localpart) do
          %{"localpart" => sub_localpart, "domain" => sub_domain} ->
            # bridged ActivityPub user
            {:puppet, sub_localpart, sub_domain}

          nil ->
            # real local user
            {:local, localpart}
        end

      %{"localpart" => localpart, "domain" => remote_domain} ->
        # remote Matrix user
        {:remote, localpart, remote_domain}

      nil ->
        {:error, :invalid_address}
    end
  end

  def local_ap_username_to_matrix(username) do
    domain = Application.fetch_env!(:activity_pub, :domain)
    # TODO usernames can be for remote matrix users
    username = String.replace_suffix(username, "@" <> domain, "")
    "@#{username}:#{domain}"
  end

  def ap_username_to_local_ap_id(username) do
    KazarmaWeb.Router.Helpers.activity_pub_url(KazarmaWeb.Endpoint, :actor, username)
  end

  def ap_to_matrix(ap_id) do
    # Logger.debug(inspect(ap_id))

    with {:ok, %ActivityPub.Actor{username: username}} <-
           ActivityPub.Actor.get_cached_by_ap_id(ap_id),
         # _ <- Logger.error(ap_id),
         # _ <- Logger.error(actor),
         {localpart, remote_domain} <-
           parse_activitypub_username(username) do
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
