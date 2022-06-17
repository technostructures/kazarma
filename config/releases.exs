# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

import Config

database_host = System.get_env("DATABASE_HOST")
database_username = System.get_env("DATABASE_USERNAME")
database_password = System.get_env("DATABASE_PASSWORD")
database_db = System.get_env("DATABASE_DB")

_ =
  (database_host && database_username && database_password && database_db) ||
    raise """
    Database environment variable missing.
    Could be one of: DATABASE_HOST, DATABASE_USERNAME, DATABASE_PASSWORD, DATABASE_DB.
    """

config :kazarma, Kazarma.Repo,
  # ssl: true,
  hostname: database_host,
  username: database_username,
  password: database_password,
  database: database_db,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

host =
  System.get_env("HOST") ||
    raise """
    environment variable HOST is missing.
    """

config :kazarma, KazarmaWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  url: [host: host, scheme: "https", port: 443],
  secret_key_base: secret_key_base

homeserver_token =
  System.get_env("HOMESERVER_TOKEN") ||
    raise """
    environment variable HOMESERVER_TOKEN is missing.
    """

access_token =
  System.get_env("ACCESS_TOKEN") ||
    raise """
    environment variable ACCESS_TOKEN is missing.
    """

matrix_url =
  System.get_env("MATRIX_URL") ||
    raise """
    environment variable MATRIX_URL is missing.
    """

config :matrix_app_service, :app_service,
  base_url: matrix_url,
  homeserver_token: homeserver_token,
  access_token: access_token

activity_pub_domain =
  System.get_env("ACTIVITY_PUB_DOMAIN") ||
    raise """
    environment variable ACTIVITY_PUB_DOMAIN is missing.
    """

config :activity_pub, :domain, activity_pub_domain

puppet_prefix = System.get_env("PUPPET_PREFIX") || "_ap_"

config :kazarma, prefix_puppet_username: puppet_prefix

bridge_remote_matrix_users = System.get_env("BRIDGE_REMOTE") == "true"
html_search = System.get_env("HTML_SEARCH") == "true"
html_activity_pub = System.get_env("HTML_AP") == "true"

config :kazarma, bridge_remote_matrix_users: bridge_remote_matrix_users
config :kazarma, html_search: html_search
config :kazarma, html_actor_view_include_remote: html_activity_pub

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:

config :kazarma, KazarmaWeb.Endpoint, server: true

# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
