# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :kazarma, env: config_env()

config :kazarma,
  ecto_repos: [Kazarma.Repo]

# Configures the endpoint
config :kazarma, KazarmaWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "KJCP3+zhA0kKrbedcdq1b46HFj715v5cHqFhsSPIL4UaiuU3duxvXFfkQJQk1/mz",
  render_errors: [
    formats: [html: KazarmaWeb.ErrorHTML, json: KazarmaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kazarma.PubSub,
  live_view: [signing_salt: "yxA/keyK"]

# Configures Elixir's Logger
config :logger,
  backends: [:console],
  level: :debug

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  colors: [enabled: true]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :mime, :types, %{
  "application/xml" => ["xml"],
  "application/xrd+xml" => ["xrd+xml"],
  "application/jrd+json" => ["jrd+json"],
  "application/activity+json" => ["activity+json"]
}

config :gettext, :default_locale, "en"

config :ex_cldr,
  default_backend: KazarmaWeb.Cldr,
  default_locale: "en"

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
  federation_publisher_modules: [ActivityPub.Federator.APPublisher],
  federation_reachability_timeout_days: 7,
  federating: true,
  rewrite_policy: []

config :http_signatures, adapter: ActivityPub.Safety.Signatures
config :tesla, adapter: Tesla.Adapter.Hackney

config :activity_pub, :http,
  proxy_url: nil,
  send_user_agent: true,
  user_agent: "kazarma bridge",
  adapter: [
    ssl_options: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      customize_hostname_check: [
        match_fun: &Kazarma.Release.ssl_hostname_check/2
      ],
      # Workaround for remote server certificate chain issues
      partial_chain: &:hackney_connect.partial_chain/1,
      versions: [:"tlsv1.2", :"tlsv1.3"]
    ]
  ]

config :kazarma, Oban,
  queues: [federator_incoming: 50, federator_outgoing: 50],
  repo: Kazarma.Repo

config :kazarma, :matrix, client: MatrixAppService.Client
config :kazarma, :activity_pub, server: ActivityPub

config :kazarma, KazarmaWeb.Gettext, default_locale: "en", locales: ~w(en fr es nb)

# @TODO not implemented
config :kazarma, bridge_remote_matrix_users: false

config :kazarma, prefix_puppet_username: "_ap_"

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

config :activity_pub, :mrf_simple,
  media_removal: [],
  media_nsfw: [],
  report_removal: [],
  accept: [],
  avatar_removal: [],
  banner_removal: [],
  reject: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
