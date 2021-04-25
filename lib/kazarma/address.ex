defmodule Kazarma.Address do
  @moduledoc """
  Functions about Matrix and ActivityPub addresses conversion.
  """
  require Logger

  def domain, do: Application.fetch_env!(:activity_pub, :domain)

  def parse_activitypub_username(username) do
    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<remote_domain>[a-z0-9\.-]+)/

    case Regex.named_captures(regex, username) do
      %{"localpart" => localpart, "remote_domain" => remote_domain} ->
        {localpart, remote_domain}

      _ ->
        nil
    end
  end

  def parse_ap_username(username) do
    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<domain>[a-z0-9\.-]+)/
    sub_regex = ~r/(?<localpart>[a-z0-9_\.-]+)=(?<domain>[a-z0-9\.-]+)/

    domain = domain()

    username =
      if String.contains?(username, "@") do
        username
      else
        "#{username}@#{domain()}"
      end

    case Regex.named_captures(regex, username) do
      %{"localpart" => localpart, "domain" => ^domain} ->
        # local Matrix user
        case Regex.named_captures(sub_regex, localpart) do
          %{"localpart" => sub_localpart, "domain" => sub_domain} ->
            # remote Matrix user
            {:remote_matrix, sub_localpart, sub_domain}

          nil ->
            # local Matrix user
            {:local_matrix, localpart}
        end

      %{"localpart" => localpart, "domain" => remote_domain} ->
        # remote ActivityPub user
        {:remote, localpart, remote_domain}

      nil ->
        {:error, :invalid_address}
    end
  end

  def parse_puppet_matrix_id(user_id) do
    regex = ~r/@ap_(?<localpart>[a-z0-9_\.-]+)=(?<remote_domain>[a-z0-9\.-]+):#{domain()}/

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

    domain = domain()

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

  def puppet_matrix_id_to_ap_username(matrix_id) do
    case parse_matrix_id(matrix_id) do
      {:puppet, sub_localpart, sub_domain} ->
        {:ok, "#{sub_localpart}@#{sub_domain}"}

      _ ->
        {:error, :not_a_puppet_user}
    end
  end

  def matrix_id_to_ap_username(matrix_id) do
    case parse_matrix_id(matrix_id) do
      {:puppet, sub_localpart, sub_domain} ->
        {:ok, "#{sub_localpart}@#{sub_domain}"}

      {:local, localpart} ->
        {:ok, "#{localpart}@#{domain()}"}

      {:remote, localpart, remote_domain} ->
        {:ok, "#{localpart}@#{remote_domain}"}

      _ ->
        {:error, :not_found}
    end
  end

  def puppet_matrix_id_to_actor(matrix_id) do
    case puppet_matrix_id_to_ap_username(matrix_id) do
      {:ok, username} ->
        ActivityPub.Actor.get_or_fetch_by_username(username)

      error ->
        error
    end
  end

  def matrix_ap_username_to_matrix_id(username) do
    case parse_ap_username(username) do
      {:remote_matrix, sub_localpart, sub_domain} ->
        {:ok, "@#{sub_localpart}:#{sub_domain}"}

      {:local_matrix, localpart} ->
        {:ok, "@#{localpart}:#{domain()}"}

      _ ->
        {:error, :not_found}
    end
  end

  def local_ap_username_to_matrix(username) do
    # TODO usernames can be for remote matrix users
    username = String.replace_suffix(username, "@" <> domain(), "")
    "@#{username}:#{domain()}"
  end

  def ap_username_to_matrix(username) do
    case parse_ap_username(username) do
      {:remote_matrix, sub_localpart, sub_domain} ->
        {:ok, "@#{sub_localpart}:#{sub_domain}"}

      {:local_matrix, localpart} ->
        {:ok, "@#{localpart}:#{domain()}"}

      {:remote, localpart, remote_domain} ->
        {:ok, "@#{localpart}=#{remote_domain}:#{domain()}"}

      {:error, :invalid_address} ->
        {:error, :not_found}
    end
  end

  def ap_localpart_to_local_ap_id(localpart) do
    KazarmaWeb.Router.Helpers.activity_pub_url(KazarmaWeb.Endpoint, :actor, localpart)
  end

  def ap_to_matrix(ap_id) do
    # Logger.debug(inspect(ap_id))

    with {:ok, %ActivityPub.Actor{username: username}} <-
           ActivityPub.Actor.get_cached_by_ap_id(ap_id),
         # _ <- Logger.error(ap_id),
         # _ <- Logger.error(actor),
         {localpart, remote_domain} <-
           parse_activitypub_username(username) do
      if remote_domain == domain() do
        "@#{localpart}:#{domain()}"
      else
        "@ap_#{localpart}=#{remote_domain}:#{domain()}"
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
