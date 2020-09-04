defmodule Kazarma.Repo.Migrations.MigrateActivityPub do
  use Ecto.Migration

  def up do
    ActivityPub.Migrations.up()
  end

  def down do
    ActivityPub.Migrations.down()
  end
end
