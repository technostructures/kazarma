# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Kazarma.MixProject do
  use Mix.Project

  def project do
    [
      app: :kazarma,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_add_apps: [:ex_unit]],
      aliases: aliases(),
      deps: deps(),
      # Docs
      docs: [
        assets: "doc_diagrams"
      ],
      test_coverage: test_coverage(System.get_env("CI"))
    ]
  end

  defp test_coverage(nil), do: []
  defp test_coverage(_), do: [tool: CoberturaCover, html_output: "cover"]

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
      {:phoenix, "~> 1.5.4"},
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.2"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:httpoison, "~> 1.5"},
      {:ex_cldr, "~> 2.23"},
      {:activity_pub, "~> 0.1.0", path: "./activity_pub"},
      {:polyjuice_client, path: "./polyjuice_client", override: true},
      {:matrix_app_service, "~> 0.2.0", path: "./matrix_app_service"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:junit_formatter, "~> 3.1", only: :test},
      {:cobertura_cover, "~> 0.9.0", only: :test},
      {:credo, "~> 1.4.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:hackney, "~> 1.17", override: true},
      {:oban, "~> 2.8", override: true}
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
