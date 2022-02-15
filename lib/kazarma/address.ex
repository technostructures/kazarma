# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Address do
  @moduledoc """
  Functions about Matrix and ActivityPub addresses conversion.
  """
  require Logger

  def domain, do: Application.fetch_env!(:activity_pub, :domain)

  def puppet_prefix, do: Application.get_env(:kazarma, :prefix_puppet_username, "ap_")

  def get_username_localpart(username) do
    username
    |> String.replace_suffix("@#{Kazarma.Address.domain()}", "")
    |> String.replace_leading("@", "")
  end

  @alphanum "A-z0-9"
  @alphanum_lowercased "a-z0-9"
  @ap_chars @alphanum <> "_"
  @matrix_chars @alphanum_lowercased <> "_\\.\\-\\/"
  @valid_domain "[#{@alphanum}][#{@alphanum}\\.\\-]*[#{@alphanum}]"

  @doc """
  Parse an ActivityPub username

  If the ActivityPub domain is controlled by the Kazarma instance, it can be:
    - :local_matrix when both the Matrix instance and ActivityPub instance are controlled by us
    ex: my_user@my_instance
    - :remote_matrix when the Matrix server isn't controlled by us
    ex: my_user=my_remote_instance@my_instance
  If the ActivityPub domain isn't controlled by us:
    - :activity_pub
    ex: my_user@my_remote_instance
  """
  def parse_ap_username(username) do
    regex = ~r/^@?(?<localpart>[#{@ap_chars}\-\.=]+)@(?<domain>#{@valid_domain})/
    sub_regex = ~r/(?<localpart>[#{@ap_chars}]+)=(?<domain>#{@valid_domain})/
    username = if String.contains?(username, "@"), do: username, else: "#{username}@#{domain()}"

    case Regex.named_captures(regex, username) do
      %{"localpart" => localpart, "domain" => domain} ->
        if domain in [domain(), KazarmaWeb.Endpoint.host()] do
          # local ActivityPub user (puppet)
          case Regex.named_captures(sub_regex, localpart) do
            %{"localpart" => sub_localpart, "domain" => sub_domain} ->
              # remote Matrix user
              {:remote_matrix, sub_localpart, sub_domain}

            nil ->
              # local Matrix user
              {:local_matrix, localpart}
          end
        else
          # remote ActivityPub user
          {:activity_pub, localpart, domain}
        end

      nil ->
        {:error, :invalid_address}
    end
  end

  @doc """
  Transform a ActivityPub username to his associated Matrix id
  """
  def ap_username_to_matrix_id(username, types \\ [:remote_matrix, :local_matrix, :activity_pub]) do
    parse_ap_username(username)
    |> filter_types(types)
    |> case do
      {:remote_matrix, sub_localpart, sub_domain} ->
        {:ok, "@#{sub_localpart}:#{sub_domain}"}

      {:local_matrix, localpart} ->
        {:ok, "@#{localpart}:#{domain()}"}

      {:activity_pub, localpart, remote_domain} ->
        {:ok, "@#{puppet_prefix()}#{localpart}=#{remote_domain}:#{domain()}"}

      _ ->
        {:error, :not_found}
    end
  end

  def ap_localpart_to_local_ap_id(localpart) do
    KazarmaWeb.Router.Helpers.activity_pub_url(KazarmaWeb.Endpoint, :actor, localpart)
  end

  def ap_id_to_matrix(ap_id) do
    case ActivityPub.Actor.get_cached_by_ap_id(ap_id) do
      {:ok, %ActivityPub.Actor{username: username}} ->
        ap_username_to_matrix_id(username)

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Parse a Matrix username

  If the Matrix domain is controlled by the Kazarma instance, it can be:
    - :activity_pub when the user belongs to a remote Matrix instance (bridging)
    The username starts with the puppet prefix and is suffixed by =remote_ap_instance
    ex: ap_user=remote_ap_instance@my_domain
    - :local_matrix when when we control the Matrix instance
    ex: my_user@my_domain
  If the Matrix domain isn't controlled by us
    - :remote_matrix ex: my_user@my_remote_instance
  """
  def parse_matrix_id(user_id) do
    domain = domain()
    regex = ~r/^@?(?<localpart>[#{@matrix_chars}=]+):(?<domain>#{@valid_domain})$/

    sub_regex =
      ~r/#{puppet_prefix()}(?<localpart>[#{@matrix_chars}]+)=(?<domain>#{@valid_domain})/

    case Regex.named_captures(regex, user_id) do
      %{"localpart" => localpart, "domain" => ^domain} ->
        # local Matrix user
        case String.starts_with?(localpart, puppet_prefix()) &&
               Regex.named_captures(sub_regex, localpart) do
          %{"localpart" => sub_localpart, "domain" => sub_domain} ->
            # bridged ActivityPub user
            {:activity_pub, String.replace_prefix(sub_localpart, puppet_prefix(), ""), sub_domain}

          _ ->
            # real local user
            {:local_matrix, localpart}
        end

      %{"localpart" => localpart, "domain" => remote_domain} ->
        # remote Matrix user
        {:remote_matrix, localpart, remote_domain}

      nil ->
        {:error, :invalid_address}
    end
  end

  @doc """
  Transform a Matrix id to his associated ActivityPub username
  """
  def matrix_id_to_ap_username(matrix_id, types \\ [:activity_pub, :local_matrix, :remote_matrix]) do
    parse_matrix_id(matrix_id)
    |> filter_types(types)
    |> case do
      {:activity_pub, sub_localpart, sub_domain} ->
        {:ok, "#{sub_localpart}@#{sub_domain}"}

      {:local_matrix, localpart} ->
        {:ok, "#{localpart}@#{domain()}"}

      {:remote_matrix, localpart, remote_domain} ->
        {:ok, "#{localpart}=#{remote_domain}@#{domain()}"}

      _ ->
        {:error, :not_found}
    end
  end

  def matrix_id_to_actor(matrix_id, types \\ [:activity_pub, :local_matrix, :remote_matrix]) do
    case matrix_id_to_ap_username(matrix_id, types) do
      {:ok, username} ->
        ActivityPub.Actor.get_or_fetch_by_username(username)

      error ->
        error
    end
  end

  defp filter_types({type, _} = t, types) do
    if type in types, do: t, else: {:error, :not_found}
  end

  defp filter_types({type, _, _} = t, types) do
    if type in types, do: t, else: {:error, :not_found}
  end
end
