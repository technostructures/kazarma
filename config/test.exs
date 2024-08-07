import Config
# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
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

config :kazarma, Oban, testing: :manual

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kazarma, KazarmaWeb.Endpoint,
  http: [port: 4002],
  url: [host: "kazarma", port: 80],
  server: false

config :kazarma, :matrix, client: Kazarma.Matrix.TestClient
config :kazarma, :activity_pub, server: Kazarma.ActivityPub.TestServer

config :matrix_app_service, :app_service,
  base_url: "http://homeserver",
  access_token: "access_token",
  homeserver_token: "homeserver_token"

config :activity_pub, :base_url, "http://kazarma"
config :activity_pub, :domain, "kazarma"

config :activity_pub, :mrf_simple, reject: ["pleroma", "kazarma"]

config :kazarma, bridge_remote_matrix_users: true
config :kazarma, html_search: true
config :kazarma, html_actor_view_include_remote: true
config :kazarma, frontpage_help: true
config :kazarma, frontpage_before_text: nil
config :kazarma, frontpage_after_text: nil

log_level =
  case System.get_env("LOG_LEVEL") do
    nil -> :critical
    level -> String.to_atom(level)
  end

config :logger, level: log_level
