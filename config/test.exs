use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :kazarma, Kazarma.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: "kazarma_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kazarma, KazarmaWeb.Endpoint,
  http: [port: 4002],
  url: [host: "kazarma", port: 80],
  server: false

config :kazarma, :matrix, client: Kazarma.Matrix.TestClient

config :matrix_app_service, :app_service,
  base_url: "http://homeserver",
  access_token: "access_token",
  homeserver_token: "homeserver_token"

config :activity_pub, :base_url, "http://kazarma"
config :activity_pub, :domain, "kazarma"

config :logger, level: :debug
