# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

import Config

########################
# Database configuration
########################

config :kazarma, Kazarma.Repo,
  # ssl: true,
  hostname: System.fetch_env!("DATABASE_HOST"),
  username: System.fetch_env!("DATABASE_USERNAME"),
  password: System.fetch_env!("DATABASE_PASSWORD"),
  database: System.fetch_env!("DATABASE_DB"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

##########################
# Appservice configuration
##########################

config :matrix_app_service, :app_service,
  base_url: System.fetch_env!("MATRIX_URL"),
  homeserver_token: System.fetch_env!("HOMESERVER_TOKEN"),
  access_token: System.fetch_env!("ACCESS_TOKEN")

###########
# Addresses
###########

config :activity_pub, :domain, System.fetch_env!("ACTIVITY_PUB_DOMAIN")

config :kazarma, prefix_puppet_username: System.get_env("PUPPET_PREFIX", "_ap_")

#######################
# General configuration
#######################

config :kazarma, KazarmaWeb.Endpoint,
  server: true,
  http: [
    port: String.to_integer(System.get_env("PORT", "4000")),
    transport_options: [socket_opts: [:inet6]]
  ],
  url: [host: System.fetch_env!("HOST"), scheme: "https", port: 443],
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

config :kazarma, bridge_remote_matrix_users: System.get_env("BRIDGE_REMOTE") == "true"
config :kazarma, html_search: System.get_env("HTML_SEARCH") == "true"
config :kazarma, html_actor_view_include_remote: System.get_env("HTML_AP") == "true"

########################
# Frontend configuration
########################

# @TODO: document
config :kazarma, frontpage_help: System.get_env("FRONTPAGE_HELP") != "false"
config :kazarma, frontpage_before_text: System.get_env("FRONTPAGE_BEFORE_TEXT")
config :kazarma, frontpage_after_text: System.get_env("FRONTPAGE_AFTER_TEXT")

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
    "warn" -> :warning
    "notice" -> :notice
    "debug" -> :debug
    _ -> :warning
  end

sentry_enabled = System.get_env("SENTRY_ENABLED") == "true"
loki_enabled = System.get_env("LOKI_ENABLED") == "true"
metrics_enabled = System.get_env("METRICS_ENABLED") == "true"
grafana_enabled = System.get_env("GRAFANA_ENABLED") == "true"

logger_backends =
  case {sentry_enabled, loki_enabled} do
    {true, true} ->
      [
        :console,
        Sentry.LoggerBackend,
        Svadilfari
      ]

    {true, false} ->
      [
        :console,
        Sentry.LoggerBackend
      ]

    {false, true} ->
      [
        :console,
        Svadilfari
      ]

    {false, false} ->
      [
        :console
      ]
  end

config :logger,
  level: log_level,
  backends: logger_backends

config :logger, Sentry.LoggerBackend,
  # Also send warn messages
  level: log_level,
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
      env: release_level
    },
    included_environments: [release_level]
end

prom_ex_grafana =
  if grafana_enabled do
    [
      host: System.fetch_env!("GRAFANA_HOST"),
      auth_token: System.fetch_env!("GRAFANA_TOKEN"),
      upload_dashboards_on_start: true,
      folder_name: "Kazarma",
      annotate_app_lifecycle: true
    ]
  else
    :disabled
  end

prom_ex_server =
  if System.get_env("METRICS_PORT") do
    [port: String.to_integer(System.get_env("METRICS_PORT"))]
  else
    :disabled
  end

config :kazarma, Kazarma.PromEx,
  disabled: !metrics_enabled,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: prom_ex_grafana,
  metrics_server: prom_ex_server

org_id = System.get_env("LOKI_ORG_ID")

loki_client_opts = if org_id, do: [org_id: org_id], else: []

if loki_enabled do
  config :logger, :svadilfari,
    metadata: [:request_id],
    max_buffer: 10,
    client: [
      url: System.fetch_env!("LOKI_HOST"),
      opts: loki_client_opts
    ],
    format: "\n[$metadata] $message\n",
    labels: [
      {"service", "kazarma"},
      {"env", release_level}
    ],
    derived_labels: {Kazarma.Logger, :derive_level}
end

default_locale = System.get_env("DEFAULT_LOCALE")

if default_locale in ["fr", "es"] do
  config :gettext, :default_locale, default_locale

  config :ex_cldr,
    default_locale: default_locale

  config :kazarma, KazarmaWeb.Gettext, default_locale: default_locale
end
