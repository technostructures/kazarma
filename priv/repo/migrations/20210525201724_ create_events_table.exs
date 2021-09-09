defmodule Kazarma.Repo.Migrations.CreateEventsTable do
  use Ecto.Migration

  def change do
    MatrixAppService.Migrations.create_events_table()
  end
end
