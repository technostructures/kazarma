# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Kazarma.MixProject do
  use Mix.Project

  def project do
    [
      app: :kazarma,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_add_apps: [:ex_unit]],
      aliases: aliases(),
      deps: deps(),
      # Docs
      docs: [
        assets: "doc_diagrams"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      releases: [kazarma: [applications: [svadilfari: :permanent, prom_ex: :permanent]]]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Kazarma.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto, "~> 3.9.0"},
      {:ecto_sql, "~> 3.9.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.22"},
      {:jason, "~> 1.3"},
      {:plug_cowboy, "~> 2.6.0", override: true},
      {:httpoison, "~> 1.5"},
      {:ex_cldr, "~> 2.33"},
      {:ex_cldr_plugs, "~> 1.2"},
      {:activity_pub, "~> 0.1.0", path: "./activity_pub"},
      {:polyjuice_client, path: "./polyjuice_client", override: true},
      {:matrix_app_service, path: "./matrix_app_service"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:junit_formatter, "~> 3.1", only: :test},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2.0", only: [:dev, :test], runtime: false},
      {:hackney, "~> 1.18.0", override: true},
      {:oban, "~> 2.13"},
      {:logger_file_backend, "~> 0.0.13"},
      {:sentry, "~> 8.0"},
      {:prom_ex, "~> 1.7"},
      {:floki, ">= 0.30.0"},
      {:phoenix_live_view, "~> 0.20.1"},
      {:phoenix_live_reload, "~> 1.4.1"},
      {:html_sanitize_ex, "~> 1.4"},
      {:ex_cldr_dates_times, "~> 2.0"},
      {:svadilfari, github: "akasprzok/svadilfari", ref: "6e55a2f"},
      {:tesla, "~> 1.7", override: true},
      {:excoveralls, "~> 0.17", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
