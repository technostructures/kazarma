# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Release do
  @moduledoc """
  Functions needed when deploying with releases.
  Can be used like this: `kazarma eval "Kazarma.Release.migrate()"`
  """
  @app :kazarma

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  @doc """
  Wrapper for the anonymous function returned by :public_key.pkix_verify_hostname_match_fun/1
  """
  def ssl_hostname_check(arg1, arg2) do
    fun = :public_key.pkix_verify_hostname_match_fun(:https)
    fun.(arg1, arg2)
  end
end
