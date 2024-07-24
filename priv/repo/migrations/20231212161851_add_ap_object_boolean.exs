# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo.Migrations.AddApObjectBoolean do
  use Ecto.Migration

  def up do
    ActivityPub.Migrations.add_object_boolean()
  end

  def down do
    ActivityPub.Migrations.drop_object_boolean()
  end
end
