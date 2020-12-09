defmodule Kazarma.Repo.Migrations.MigrateMatrixAppServiceBridge do
  use Ecto.Migration

  def change do
    MatrixAppService.Migrations.change()
  end
end
