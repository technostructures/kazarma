# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo.Migrations.MigrateActivityPub do
  use Ecto.Migration

  def up do
    ActivityPub.Migrations.up()
  end

  def down do
    ActivityPub.Migrations.down()
  end
end
