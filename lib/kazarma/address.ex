# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Address do
  @moduledoc """
  Functions about Matrix and ActivityPub addresses conversion.
  """

  alias ActivityPub.Actor

  @alphanum "A-z0-9"
  @alphanum_lowercased "a-z0-9"
  @ap_chars @alphanum <> "_"
  @matrix_chars @alphanum_lowercased <> "_\\.\\-\\/"
  @valid_domain "[#{@alphanum}][#{@alphanum}\\.\\-]*[#{@alphanum}]"

  @matrix_puppet_separation "___"
  @ap_puppet_separation "___"

  def domain, do: Application.fetch_env!(:activity_pub, :domain)

  def puppet_prefix, do: Application.get_env(:kazarma, :prefix_puppet_username, "_ap_")

  # @TODO: make configurable
  def relay_localpart, do: "relay"

  def relay_username, do: "#{relay_localpart()}@#{domain()}"

  def relay_matrix_id, do: "@#{relay_localpart()}:#{domain()}"

  def relay_ap_id,
    do:
      KazarmaWeb.Router.Helpers.activity_pub_url(
        KazarmaWeb.Endpoint,
        :actor,
        "-",
        relay_localpart()
      )

  def relay_actor do
    {:ok, actor} = ActivityPub.Actor.get_cached_by_ap_id(relay_ap_id())
    actor
  end

  def get_username_localpart(username) do
    username
    |> String.replace_suffix("@#{Kazarma.Address.domain()}", "")
    |> String.replace_leading("@", "")
  end

  def get_matrix_id_localpart(username) do
    username
    |> String.replace_suffix(":#{Kazarma.Address.domain()}", "")
    |> String.replace_leading("@", "")
  end

  def localpart(%Actor{username: username}) do
    [localpart, _server] = String.split(username, "@")
    localpart
  end

  def server(%Actor{username: username}) do
    [_localpart, server] = String.split(username, "@")
    server
  end

  @doc """
  Parses an ActivityPub username.

  It can be:
    - `:activity_pub`: a user from an ActivityPub instance
      eg: `user@remote_activity_pub`
    - `:local_matrix`: a Matrix user from the bridged instance
      eg: `user@instance`
    - `:remote_matrix`: a Matrix user from another Matrix instance (if activated)
      eg: `user___remote_matrix_instance@instance`
  """
  def parse_ap_username(username) do
    regex = ~r/^@?(?<localpart>[#{@ap_chars}\-\.=]+)@(?<domain>#{@valid_domain})/

    sub_regex =
      ~r/(?<localpart>[#{@ap_chars}]+)#{@ap_puppet_separation}(?<domain>#{@valid_domain})/

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
        {:ok,
         "@" <>
           puppet_prefix() <>
           String.downcase(localpart) <>
           @matrix_puppet_separation <> remote_domain <> ":" <> domain()}

      _ ->
        {:error, :not_found}
    end
  end

  def ap_localpart_to_local_ap_id(localpart) do
    KazarmaWeb.Router.Helpers.activity_pub_url(KazarmaWeb.Endpoint, :actor, "-", localpart)
  end

  def ap_id_to_matrix(ap_id, types \\ [:remote_matrix, :local_matrix, :activity_pub]) do
    case Actor.get_cached_by_ap_id(ap_id) do
      {:ok, %Actor{username: username}} ->
        ap_username_to_matrix_id(username, types)

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Parses a Matrix username

  It can be:
    - `:activity_pub`: a puppet user corresponding to a remote ActivityPub instance
      eg: `user___remote_activity_pub@instance`
    - `:local_matrix`: a Matrix user from the bridged instance
      eg: `user@instance`
    - `:remote_matrix`: a Matrix user from another Matrix instance (if activated)
      eg: `user@remote_matrix_instance`
  """
  def parse_matrix_id(user_id) do
    domain = domain()
    regex = ~r/^@?(?<localpart>[#{@matrix_chars}=]+):(?<domain>#{@valid_domain})$/

    sub_regex =
      ~r/#{puppet_prefix()}(?<localpart>[#{@matrix_chars}]+)#{@matrix_puppet_separation}(?<domain>#{@valid_domain})/

    case Regex.named_captures(regex, user_id) do
      # @TODO: make configurable
      %{"localpart" => "_kazarma", "domain" => ^domain} ->
        {:appservice_bot, "_kazarma"}

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

      {:appservice_bot, localpart} ->
        {:ok, "#{localpart}@#{domain()}"}

      {:local_matrix, localpart} ->
        {:ok, "#{localpart}@#{domain()}"}

      {:remote_matrix, localpart, remote_domain} ->
        {:ok, localpart <> @matrix_puppet_separation <> remote_domain <> "@" <> domain()}

      _ ->
        {:error, :not_found}
    end
  end

  def matrix_id_to_actor(matrix_id, types \\ [:activity_pub, :local_matrix, :remote_matrix]) do
    case matrix_id_to_ap_username(matrix_id, types) do
      {:ok, username} ->
        Actor.get_or_fetch_by_username(username)

      error ->
        error
    end
  end

  def matrix_mention_tag(matrix_id, display_name) do
    """
    <a href="https://matrix.to/#/<%= matrix_id %>"><%= display_name %></a>
    """
    |> EEx.eval_string(
      matrix_id: matrix_id,
      display_name: display_name
    )
  end

  def unchecked_matrix_id_to_actor(matrix_id) do
    case matrix_id_to_actor(matrix_id) do
      {:ok, actor} -> actor
      _ -> nil
    end
  end

  defp filter_types({type, _} = t, types) do
    if type in types, do: t, else: {:error, :not_found}
  end

  defp filter_types({type, _, _} = t, types) do
    if type in types, do: t, else: {:error, :not_found}
  end
end
