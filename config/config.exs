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
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# ActivityPub configuration
config :activity_pub, :adapter, Kazarma.MyAdapter
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

config :activity_pub, Oban, queues: [federator_incoming: 50, federator_outgoing: 50]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
