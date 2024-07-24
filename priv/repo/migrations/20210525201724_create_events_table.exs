# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo.Migrations.CreateEventsTable do
  use Ecto.Migration

  def change do
    MatrixAppService.Migrations.create_events_table()
  end
end
