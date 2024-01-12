# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo.Migrations.CreateObanPeers do
  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 11)

  def down, do: Oban.Migrations.down(version: 11)
end
