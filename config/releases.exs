import Config

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :kazarma, Kazarma.Repo,
  # ssl: true,
  url: database_url,
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

puppet_prefix = System.get_env("PUPPET_PREFIX") || "ap_"

config :kazarma, prefix_puppet_username: puppet_prefix

bridge_remote_matrix_users = !is_nil(System.get_env("BRIDGE_REMOTE"))
html_search = !is_nil(System.get_env("HTML_SEARCH"))
html_activity_pub = !is_nil(System.get_env("HTML_AP"))

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
