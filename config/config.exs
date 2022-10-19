# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :kazarma,
  ecto_repos: [Kazarma.Repo]

# Configures the endpoint
config :kazarma, KazarmaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "KJCP3+zhA0kKrbedcdq1b46HFj715v5cHqFhsSPIL4UaiuU3duxvXFfkQJQk1/mz",
  render_errors: [view: KazarmaWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Kazarma.PubSub,
  live_view: [signing_salt: "yxA/keyK"]

# Configures Elixir's Logger
config :logger, backends: [:console, {LoggerFileBackend, :file_log}, Sentry.LoggerBackend]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  colors: [enabled: true]

config :logger, :file_log,
  format: "$message\n",
  path: "event.log",
  level: :debug,
  metadata_filter: [device: :event]

config :logger, :file_log,
  format: "$message\n",
  path: "activity.log",
  level: :debug,
  metadata_filter: [device: :activity]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :mime, :types, %{
  "application/xml" => ["xml"],
  "application/xrd+xml" => ["xrd+xml"],
  "application/jrd+json" => ["jrd+json"],
  "application/activity+json" => ["activity+json"],
  "application/ld+json" => ["activity+json"]
}

# ActivityPub configuration
config :activity_pub, :adapter, Kazarma.ActivityPub.Adapter
config :activity_pub, :repo, Kazarma.Repo

config :activity_pub, :mrf_simple,
  media_removal: [],
  media_nsfw: [],
  report_removal: [],
  accept: [],
  avatar_removal: [],
  banner_removal: []

config :activity_pub, :instance,
  federation_publisher_modules: [ActivityPubWeb.Publisher],
  federation_reachability_timeout_days: 7,
  federating: true,
  rewrite_policy: []

config :http_signatures, adapter: ActivityPub.Signature
config :tesla, adapter: Tesla.Adapter.Hackney

config :activity_pub, :http,
  proxy_url: nil,
  send_user_agent: true,
  adapter: [
    ssl_options: [
      # Workaround for remote server certificate chain issues
      partial_chain: &:hackney_connect.partial_chain/1,
      # We don't support TLS v1.3 yet
      versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"]
    ]
  ]

config :kazarma, Oban,
  queues: [federator_incoming: 50, federator_outgoing: 50],
  repo: Kazarma.Repo

config :kazarma, :matrix, client: MatrixAppService.Client
config :kazarma, :activity_pub, server: ActivityPub

config :kazarma, KazarmaWeb.Gettext, default_locale: "en", locales: ~w(en fr)

# @TODO not implemented
config :kazarma, bridge_remote_matrix_users: false

config :kazarma, prefix_puppet_username: "_ap_"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
