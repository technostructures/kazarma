# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Address do
  @moduledoc """
  Functions about Matrix and ActivityPub addresses conversion.
  """

  require Logger

  alias ActivityPub.Actor

  def ap_domain, do: Application.fetch_env!(:activity_pub, :domain)

  def matrix_domain, do: Application.fetch_env!(:kazarma, :matrix_domain)

  # def puppet_prefix, do: Application.get_env(:kazarma, :prefix_puppet_username, "_ap_")

  # @TODO: make configurable
  def command_bot_localpart, do: "_kazarma"

  def command_bot_matrix_id, do: "@#{command_bot_localpart()}:#{matrix_domain()}"

  def activity_bot_localpart, do: "activity_bridge"

  def activity_bot_username, do: "#{activity_bot_localpart()}@#{ap_domain()}"

  def activity_bot_matrix_id, do: "@#{activity_bot_localpart()}:#{ap_domain()}"

  def activity_bot_ap_id,
    do:
      KazarmaWeb.Router.Helpers.activity_pub_url(
        KazarmaWeb.Endpoint,
        :actor,
        "-",
        activity_bot_localpart()
      )

  def activity_bot_actor do
    {:ok, actor} = ActivityPub.Actor.get_cached(ap_id: activity_bot_ap_id())
    actor
  end

  def profile_bot_localpart, do: "profile_bridge"

  def profile_bot_username, do: "#{profile_bot_localpart()}@#{ap_domain()}"

  def profile_bot_matrix_id, do: "@#{profile_bot_localpart()}:#{ap_domain()}"

  def profile_bot_ap_id,
    do:
      KazarmaWeb.Router.Helpers.activity_pub_url(
        KazarmaWeb.Endpoint,
        :actor,
        "-",
        profile_bot_localpart()
      )

  def profile_bot_actor do
    {:ok, actor} = ActivityPub.Actor.get_cached(ap_id: profile_bot_ap_id())
    actor
  end

  # @TODO: make configurable
  def application_localpart, do: "kazarma"

  def application_username, do: "#{application_localpart()}@#{ap_domain()}"

  def application_matrix_id, do: "@#{application_localpart()}:#{matrix_domain()}"

  def application_ap_id,
    do:
      KazarmaWeb.Router.Helpers.index_url(
        KazarmaWeb.Endpoint,
        :index
      )

  def application_actor do
    {:ok, actor} = ActivityPub.Actor.get_cached(ap_id: application_ap_id())
    actor
  end

  def localpart(%{local: false, username: username}) when not is_nil(username) do
    [localpart, _server] = String.split(username, "@")
    localpart
  end

  def localpart(%{local: false, data: %{"username" => username}}) do
    [localpart, _server] = String.split(username, "@")
    localpart
  end

  def localpart(%{local: true, ap_id: ap_id}) do
    %URI{host: host, path: path} = URI.parse(ap_id)

    %{path_params: %{"localpart" => localpart}} =
      Phoenix.Router.route_info(KazarmaWeb.Router, "GET", path, host)

    localpart
  end

  def localpart(%{local: true, data: %{"id" => ap_id}}) do
    %URI{host: host, path: path} = URI.parse(ap_id)

    %{path_params: %{"localpart" => localpart}} =
      Phoenix.Router.route_info(KazarmaWeb.Router, "GET", path, host)

    localpart
  end

  def server(%{local: false, username: username}) when not is_nil(username) do
    [_localpart, server] = String.split(username, "@")
    server
  end

  def server(%{local: false, data: %{"username" => username}}) do
    [_localpart, server] = String.split(username, "@")
    server
  end

  def server(%{local: true, ap_id: ap_id}) do
    %URI{host: host, path: path} = URI.parse(ap_id)

    %{path_params: %{"server" => server}} =
      Phoenix.Router.route_info(KazarmaWeb.Router, "GET", path, host)

    server
  end

  def server(%{local: true, data: %{"id" => ap_id}}) do
    %URI{host: host, path: path} = URI.parse(ap_id)

    %{path_params: %{"server" => server}} =
      Phoenix.Router.route_info(KazarmaWeb.Router, "GET", path, host)

    server
  end

  def matrix_id_localpart(matrix_id) do
    matrix_id =
      String.replace_leading(matrix_id, "@", "")

    [localpart, _domain] = String.split(matrix_id, ":")

    localpart
  end

  def should_bridge_local_matrix_user() do
    Kazarma.Config.private_bridge?()
  end

  def should_bridge_remote_matrix_user() do
    Kazarma.Config.public_bridge?()
  end

  def should_bridge_actor(%ActivityPub.Actor{local: true}) do
    true
  end

  def should_bridge_actor(actor) do
    if Kazarma.Config.private_bridge?() do
      true
    else
      match?(%{}, Kazarma.Bridge.get_user_by_remote_id(actor.ap_id))
    end
  end

  def get_actor(query) do
    case get_user(query) do
      %{data: %{"ap_data" => ap_data, "keys" => keys}} ->
        Kazarma.ActivityPub.Actor.build_actor_from_data(ap_data, keys)

      %{remote_id: ap_id} ->
        case ActivityPub.Actor.get_cached(ap_id: ap_id) do
          {:ok, actor} -> actor
          _ -> nil
        end

      nil ->
        nil
    end
  end

  def get_user(matrix_id: matrix_id) do
    case Kazarma.Bridge.get_user_by_local_id(matrix_id) do
      %{} = bridged_user ->
        bridged_user

      _ ->
        do_get_user(matrix_id: matrix_id)
    end
  end

  def get_user(ap_id: ap_id) do
    case Kazarma.Bridge.get_user_by_remote_id(ap_id) do
      %{} = bridged_user ->
        bridged_user

      _ ->
        do_get_user(ap_id: ap_id)
    end
  end

  def get_user(username: username) do
    do_get_user(username: username)
  end

  @doc """
  this function doesn't check if users should be bridged
  it only dispatches to corresponding functions based on
  real network of the user
  """
  def do_get_user(matrix_id: matrix_id) do
    # we can't know if it's a puppet or real Matrix user
    # based on whether it's on local homeserver
    # because puppets and local users coexist.
    # we can still avoir a check if we don't bridge local users

    if String.ends_with?(matrix_id, ":#{matrix_domain()}") && !should_bridge_local_matrix_user() do
      # @alice.mastodon.org:kazarma

      get_user_for_actor(matrix_id: matrix_id)
    else
      # @alice.mastodon.org:kazarma

      # @alice:matrix.org
      # @alice:kazarma

      get_user_for_actor(matrix_id: matrix_id) ||
        get_user_for_matrix_user(matrix_id: matrix_id)
    end
  end

  def do_get_user(ap_id: ap_id) do
    %URI{host: host} = URI.parse(ap_id)

    if host == ap_domain() do
      get_user_for_matrix_user(ap_id: ap_id)
    else
      get_user_for_actor(ap_id: ap_id)
    end
  end

  def do_get_user(username: username) do
    if String.ends_with?(username, "@#{ap_domain()}") do
      # @alice.matrix.org@kazarma
      # @alice@kazarma

      get_user_for_matrix_user(username: username)
    else
      # @alice@mastodon.org

      get_user_for_actor(username: username)
    end
  end

  def get_user_for_actor(matrix_id: matrix_id) do
    # @alice.mastodon.org:kazarma

    username =
      matrix_id
      |> String.replace_leading("@", "")

    if String.ends_with?(username, ":#{Kazarma.Address.matrix_domain()}") do
      try_remote_actor(String.replace_suffix(username, ":#{Kazarma.Address.matrix_domain()}", ""))
    end
  end

  def get_user_for_actor(username: username) do
    # @alice@mastodon.org

    get_or_fetch_ap_user(username: username)
  end

  def get_user_for_actor(ap_id: ap_id) do
    get_or_fetch_ap_user(ap_id: ap_id)
  end

  def get_user_for_matrix_user(matrix_id: matrix_id) do
    # @alice:matrix.org
    # @alice:kazarma

    [localpart, domain] = String.split(matrix_id, ":")

    localpart =
      localpart
      |> String.replace_leading("@", "")

    if (domain == matrix_domain() && should_bridge_local_matrix_user()) ||
         (domain != matrix_domain() && should_bridge_remote_matrix_user()) do
      get_or_fetch_matrix_user(localpart, domain)
    end
  end

  def get_user_for_matrix_user(username: username) do
    username_localpart =
      case String.split(username, "@") do
        [_, localpart, _] -> localpart
        [localpart, _] -> localpart
        [localpart] -> localpart
      end

    (should_bridge_local_matrix_user() &&
       get_or_fetch_matrix_user(username_localpart, matrix_domain())) ||
      (should_bridge_remote_matrix_user() && try_remote_matrix_user(username_localpart)) ||
      nil
  end

  def get_user_for_matrix_user(ap_id: ap_id) do
    with %URI{host: host, path: path} <- URI.parse(ap_id),
         %{path_params: %{"server" => server, "localpart" => localpart}} <-
           Phoenix.Router.route_info(KazarmaWeb.Router, "GET", path, host) do
      cond do
        # server == "-" && localpart == activity_bot_localpart() && Kazarma.Config.is_public_bridge() ->
        server == "-" && should_bridge_local_matrix_user() ->
          get_or_fetch_matrix_user(localpart, matrix_domain())

        server != "-" && should_bridge_remote_matrix_user() ->
          get_or_fetch_matrix_user(localpart, server)

        true ->
          nil
      end
    end
  end

  def try_remote_actor(username) do
    match_domain(username)
    |> Enum.find_value(fn {localpart, domain} ->
      get_or_fetch_ap_user(username: "#{localpart}@#{domain}")
    end)
  end

  def get_or_fetch_ap_user(query) do
    # IO.puts("#{localpart}@#{domain}")

    case Actor.get_cached_or_fetch(query) do
      {:ok, actor} ->
        maybe_create_matrix_puppet(actor)

      _ ->
        nil
    end
  end

  def maybe_create_matrix_puppet(actor) do
    if should_bridge_actor(actor) do
      create_matrix_puppet_if_not_exists(actor)
    end
  end

  def create_matrix_puppet_if_not_exists(actor) do
    case Kazarma.Bridge.get_user_by_remote_id(actor.ap_id) do
      %{} = bridged_user ->
        bridged_user

      _ ->
        create_matrix_puppet(actor)
    end
  end

  def create_matrix_puppet(%Actor{
        username: username,
        ap_id: ap_id,
        data: data
      }) do
    with [localpart, domain] <- String.split(username, "@"),
         matrix_id = "@#{localpart}.#{domain}:#{Kazarma.Address.matrix_domain()}",
         {:ok, %{"user_id" => ^matrix_id}} <-
           Kazarma.Matrix.Client.register(matrix_id) do
      name = Map.get(data, "name") || Map.get(data, "preferredUsername")
      Kazarma.Matrix.Client.put_displayname(matrix_id, name)
      avatar_url = get_in(data, ["icon", "url"])
      if avatar_url, do: Kazarma.Matrix.Client.upload_and_set_avatar(matrix_id, avatar_url)

      {:ok, user} =
        Kazarma.Bridge.create_user(%{
          local_id: matrix_id,
          remote_id: ap_id,
          data: %{}
        })

      Kazarma.Logger.log_created_puppet(user,
        type: :matrix
      )

      # gate if PUBLIC_BRIDGE and uncomment
      # Kazarma.RoomType.ApUser.create_outbox_if_public_group(actor)

      user
    else
      {:error, _code, %{"error" => error}} ->
        Logger.error(error)
        nil

      {:error, error} ->
        Logger.error(error)
        nil

      other ->
        Logger.debug(inspect(other))
        nil
    end
  end

  def try_remote_matrix_user(username_localpart) do
    match_domain(username_localpart)
    |> Enum.find_value(fn {localpart, domain} ->
      get_or_fetch_matrix_user(localpart, domain)
    end)
  end

  # matches alice.domain.com and below
  @regex_domain ~r/(?<localpart>.+)\.(?<domain>.+\..{2,})/
  # matches alice.sub.domain.com and below
  @regex_subdomain ~r/(?<localpart>.+)\.(?<domain>.+\..+\..{2,})/
  # matches alice.sub.sub.domain.com and below
  @regex_subsubdomain ~r/(?<localpart>.+)\.(?<domain>.+\..+\..+\..{2,})/

  def match_domain(username),
    do: match_domain(username, [@regex_domain, @regex_subdomain, @regex_subsubdomain])

  def match_domain(_, []), do: []

  def match_domain(username, [regex | other_regexes]) do
    case Regex.named_captures(regex, username) do
      nil ->
        []

      %{"localpart" => localpart, "domain" => domain} ->
        [{localpart, domain} | match_domain(username, other_regexes)]
    end
  end

  def get_or_fetch_matrix_user(localpart, domain) do
    case Kazarma.Bridge.get_user_by_local_id("@#{localpart}:#{domain}") do
      %{} = bridged_user ->
        Logger.debug("local user found in database")

        bridged_user

      _ ->
        Logger.debug("local user not found in database")

        fetch_matrix_user(localpart, domain)
    end
  end

  def fetch_matrix_user(localpart, domain) do
    matrix_id = "@#{localpart}:#{domain}"

    Logger.debug("trying to fetch #{matrix_id}")

    case Kazarma.Matrix.Client.get_profile(matrix_id) do
      {:ok, profile} ->
        Logger.debug("user found in Matrix")

        actor = build_actor_from_profile(localpart, domain, profile)

        {:ok, user} =
          Kazarma.Bridge.create_user(%{
            local_id: matrix_id,
            remote_id: actor.ap_id,
            data: %{"ap_data" => actor.data, "keys" => actor.keys}
          })

        Kazarma.Logger.log_created_puppet(user,
          type: :ap
        )

        user

      _ ->
        nil
    end
  end

  def build_actor_from_profile(localpart, domain, profile) do
    host = if domain == matrix_domain(), do: "-", else: domain

    ap_id =
      KazarmaWeb.Router.Helpers.activity_pub_url(KazarmaWeb.Endpoint, :actor, host, localpart)

    avatar_url =
      profile["avatar_url"] && Kazarma.Matrix.Client.get_media_url(profile["avatar_url"])

    {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

    Kazarma.ActivityPub.Actor.build_actor(%{
      localpart: localpart,
      domain: host,
      ap_id: ap_id,
      displayname: profile["displayname"],
      avatar_url: avatar_url,
      keys: keys
    })
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
end
