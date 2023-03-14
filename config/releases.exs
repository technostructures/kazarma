# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

import Config

########################
# Database configuration
########################

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

##########################
# Appservice configuration
##########################

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

###########
# Addresses
###########

activity_pub_domain =
  System.get_env("ACTIVITY_PUB_DOMAIN") ||
    raise """
    environment variable ACTIVITY_PUB_DOMAIN is missing.
    """

config :activity_pub, :domain, activity_pub_domain

puppet_prefix = System.get_env("PUPPET_PREFIX") || "_ap_"

config :kazarma, prefix_puppet_username: puppet_prefix

#######################
# General configuration
#######################

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

bridge_remote_matrix_users = System.get_env("BRIDGE_REMOTE") == "true"
html_search = System.get_env("HTML_SEARCH") == "true"
html_activity_pub = System.get_env("HTML_AP") == "true"

config :kazarma, bridge_remote_matrix_users: bridge_remote_matrix_users
config :kazarma, html_search: html_search
config :kazarma, html_actor_view_include_remote: html_activity_pub

########################
# Frontend configuration
########################

frontpage_help = System.get_env("FRONTPAGE_HELP") != "false"
frontpage_before_text = System.get_env("FRONTPAGE_BEFORE_TEXT")
frontpage_after_text = System.get_env("FRONTPAGE_AFTER_TEXT")

config :kazarma, frontpage_help: frontpage_help
config :kazarma, frontpage_before_text: frontpage_before_text
config :kazarma, frontpage_after_text: frontpage_after_text

###############
# Observability
###############

log_level =
  case System.get_env("LOG_LEVEL") do
    "debug" -> :debug
    "emergency" -> :emergency
    "alert" -> :alert
    "critical" -> :critical
    "error" -> :error
    "warning" -> :warning
    "warn" -> :warn
    "notice" -> :notice
    "debug" -> :debug
    _ -> :info
  end

config :logger,
  level: log_level,
  backends: [
    :console,
    Sentry.LoggerBackend,
    Svadilfari
  ]

config :logger, Sentry.LoggerBackend,
  # Also send warn messages
  level: :warn,
  # Send messages from Plug/Cowboy
  excluded_domains: [],
  # Include metadata added with `Logger.metadata([foo_bar: "value"])`
  # metadata: [:foo_bar],
  # Send messages like `Logger.error("error")` to Sentry
  capture_log_messages: true

sentry_dsn = System.get_env("SENTRY_DSN")
release_level = System.get_env("RELEASE_LEVEL") || "production"

if sentry_dsn do
  config :sentry,
    dsn: sentry_dsn,
    environment_name: release_level,
    enable_source_code_context: true,
    root_source_code_path: File.cwd!(),
    tags: %{
      env: "production"
    },
    included_environments: [release_level]
end

config :kazarma, Kazarma.PromEx,
  disabled: System.get_env("ENABLE_PROM_EX") != "true",
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:

config :kazarma, KazarmaWeb.Endpoint, server: true

# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
