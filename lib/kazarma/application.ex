# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start gathering events for Prometheus
      Kazarma.PromEx,
      # Start the Ecto repository
      Kazarma.Repo,
      # Start the Telemetry supervisor
      KazarmaWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Kazarma.PubSub},
      # Start the Endpoint (http/https)
      KazarmaWeb.Endpoint,
      {Oban, oban_config()}
      # Start a worker by calling: Kazarma.Worker.start_link(arg)
      # {Kazarma.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Kazarma.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    KazarmaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Conditionally disable crontab, queues, or plugins here.
  defp oban_config do
    Application.get_env(:kazarma, Oban)
  end
end
