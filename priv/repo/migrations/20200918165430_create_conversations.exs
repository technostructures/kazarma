defmodule Kazarma.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :matrix_id, :string
      add :ap_id, :string
      add :members, :map

      timestamps()
    end

    create unique_index(:conversations, [:matrix_id])
    create unique_index(:conversations, [:ap_id])
  end
end
