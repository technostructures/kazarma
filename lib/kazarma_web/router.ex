# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Router do
  use KazarmaWeb, :router

  use MatrixAppServiceWeb.Routes
  use ActivityPubWeb.Router

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  # scope "/api", KazarmaWeb do
  #   pipe_through :api
  # end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session

    plug Cldr.Plug.SetLocale,
      apps: [cldr: KazarmaWeb.Cldr, gettext: KazarmaWeb.Gettext],
      from: [:query, :path, :body, :cookie, :accept_language],
      param: "locale"

    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", KazarmaWeb do
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
end
