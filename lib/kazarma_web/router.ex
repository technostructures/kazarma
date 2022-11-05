# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Router do
  use KazarmaWeb, :router

  use MatrixAppServiceWeb.Routes
  # use ActivityPubWeb.Router

  pipeline :accepts_html do
    plug(:accepts, ["html"])
  end

  pipeline :accepts_html_and_json do
    plug(:accepts, ["activity+json", "json", "html"])
    plug(KazarmaWeb.LiveOrJsonPlug)
  end

  pipeline :browser do
    plug :fetch_session

    plug Cldr.Plug.PutLocale,
      apps: [cldr: KazarmaWeb.Cldr, gettext: KazarmaWeb.Gettext],
      from: [:query, :path, :body, :cookie, :accept_language]

    plug Cldr.Plug.AcceptLanguage,
      cldr_backend: KazarmaWeb.Cldr

    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_root_layout, {KazarmaWeb.LayoutView, :root}
  end

  scope "/", KazarmaWeb do
    pipe_through :accepts_html
    pipe_through :browser

    get "/", IndexController, :index

    post "/search", SearchController, :search
  end

  MatrixAppServiceWeb.Routes.routes(
    base_url: :config,
    access_token: :config,
    homeserver_token: :config,
    transaction_adapter: Kazarma.Matrix.Transaction,
    room_adapter: Kazarma.Matrix.Room,
    user_adapter: Kazarma.Matrix.User,
    path: "/matrix"
  )

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Application.fetch_env!(:kazarma, :env) in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: KazarmaWeb.Telemetry
    end
  end

  # ActivityPub router, modified to also have live view routes
  pipeline :well_known do
    plug(:accepts, ["json", "jrd+json", "xml", "xrd+xml"])
  end

  pipeline :activity_pub do
    plug(:accepts, ["activity+json", "json"])
  end

  pipeline :signed_activity_pub do
    plug(:accepts, ["activity+json", "json"])
    plug(ActivityPubWeb.Plugs.HTTPSignaturePlug)
  end

  scope "/.well-known", ActivityPubWeb do
    pipe_through(:well_known)

    get "/webfinger", WebFingerController, :webfinger
  end

  scope "/", ActivityPubWeb do
    pipe_through(:activity_pub)

    # get "/objects/:uuid", ActivityPubController, :object
    # get "/actors/:username", ActivityPubController, :actor
    get "/actors/:username/followers", ActivityPubController, :followers
    get "/actors/:username/following", ActivityPubController, :following
    get "/actors/:username/outbox", ActivityPubController, :noop
  end

  scope "/", KazarmaWeb do
    pipe_through(:accepts_html_and_json)
    pipe_through(:browser)

    live("/objects/:uuid", Object, :object, as: :activity_pub)
    live("/actors/:username", Actor, :actor, as: :activity_pub)
  end

  scope "/", ActivityPubWeb do
    pipe_through(:signed_activity_pub)

    post "/actors/:username/inbox", ActivityPubController, :inbox
    post "/shared_inbox", ActivityPubController, :inbox
  end
end
