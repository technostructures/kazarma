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

  def parse_ap_username(username) do
    regex = ~r/(?<localpart>[a-z0-9_\.-=]+)@(?<domain>[a-z0-9\.-]+)/
    sub_regex = ~r/(?<localpart>[a-z0-9_\.-]+)=(?<domain>[a-z0-9\.-]+)/

    username =
      if String.contains?(username, "@") do
        username
      else
        "#{username}@#{domain()}"
      end

    %{"localpart" => localpart, "domain" => domain} = Regex.named_captures(regex, username)

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
      {:remote, localpart, domain}
    end
  end

  def ap_username_to_matrix_id(username, types \\ [:remote_matrix, :local_matrix, :remote]) do
    parse_ap_username(username)
    |> filter_types(types)
    |> case do
      {:remote_matrix, sub_localpart, sub_domain} ->
        {:ok, "@#{sub_localpart}:#{sub_domain}"}

      {:local_matrix, localpart} ->
        {:ok, "@#{localpart}:#{domain()}"}

      {:remote, localpart, remote_domain} ->
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

  def parse_matrix_id(user_id) do
    regex = ~r/@(?<localpart>[a-z0-9_.\-=]+):(?<domain>[a-z0-9\.-]+)/
    sub_regex = ~r/(?<localpart>[a-z0-9_.\-]+)=(?<domain>[a-z0-9\.-]+)/
    domain = domain()

    case Regex.named_captures(regex, user_id) do
      %{"localpart" => localpart, "domain" => ^domain} ->
        # local Matrix user
        case String.starts_with?(localpart, puppet_prefix()) &&
               Regex.named_captures(sub_regex, localpart) do
          %{"localpart" => sub_localpart, "domain" => sub_domain} ->
            # bridged ActivityPub user
            {:puppet, String.replace_prefix(sub_localpart, puppet_prefix(), ""), sub_domain}

          _ ->
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

  def matrix_id_to_ap_username(matrix_id, types \\ [:puppet, :local, :remote]) do
    parse_matrix_id(matrix_id)
    |> filter_types(types)
    |> case do
      {:puppet, sub_localpart, sub_domain} ->
        {:ok, "#{sub_localpart}@#{sub_domain}"}

      {:local, localpart} ->
        {:ok, "#{localpart}@#{domain()}"}

      {:remote, localpart, remote_domain} ->
        {:ok, "#{localpart}=#{remote_domain}@#{domain()}"}

      _ ->
        {:error, :not_found}
    end
  end

  def matrix_id_to_actor(matrix_id, types \\ [:puppet, :local, :remote]) do
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
