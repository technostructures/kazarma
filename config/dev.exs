import Mix.Config
# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
# Configure your database
config :kazarma, Kazarma.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DB") || "kazarma_dev",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :kazarma, KazarmaWeb.Endpoint,
  http: [port: 4000],
  live_reload: [interval: 1000],
  # url: [host: "kazarma.kazarma.local", scheme: "https", port: 443],
  url: [host: "kazarma.kazarma.local", scheme: "http", port: 80],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode=development",
      "--watch",
      "--watch-options-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Note that this task requires Erlang/OTP 20 or later.
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :kazarma, KazarmaWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/phoenix_new_web/(live|views)/.*(ex)$",
      ~r"lib/phoenix_new_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# MatrixAppService configuration
config :matrix_app_service, :app_service,
  base_url: "http://matrix.kazarma.local",
  access_token:
    "MDAyMGxvY2F0aW9uIG1hdHJpeC5pbWFnby5sb2NhbAowMDEzaWRlbnRpZmllciBrZXkKMDAxMGNpZCBnZW4gPSAxCjAwMmNjaWQgdXNlcl9pZCA9IEBhbGljZTptYXRyaXguaW1hZ28ubG9jYWwKMDAxNmNpZCB0eXBlID0gYWNjZXNzCjAwMjFjaWQgbm9uY2UgPSAjRC5ieWJrMEUuMU0qT0xJCjAwMmZzaWduYXR1cmUg-jGyjY9CK07mRt1h4p_86D6SJr1ZqrGr8YlsIW_jLtMK",
  homeserver_token:
    "MDAyMGxvY2F0aW9uIG1hdHJpeC5pbWFnby5sb2NhbAowMDEzaWRlbnRpZmllciBrZXkKMDAxMGNpZCBnZW4gPSAxCjAwMmNjaWQgdXNlcl9pZCA9IEBhbGljZTptYXRyaXguaW1hZ28ubG9jYWwKMDAxNmNpZCB0eXBlID0gYWNjZXNzCjAwMjFjaWQgbm9uY2UgPSBjcX4jazVTUDNeUlk2WnRECjAwMmZzaWduYXR1cmUg_K2biF-xm5ue7985RkAomVadF7yfy3UiEpH-e15m0esK"

config :activity_pub, :domain, "kazarma.local"

config :kazarma, bridge_remote_matrix_users: true
config :kazarma, html_search: true
config :kazarma, html_actor_view_include_remote: true
config :kazarma, frontpage_help: true
config :kazarma, frontpage_before_text: nil
config :kazarma, frontpage_after_text: nil

config :matrix_app_service, ignore_exceptions: true
