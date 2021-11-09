# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo.Migrations.MigrateMatrixAppServiceBridge do
  use Ecto.Migration

  def change do
    MatrixAppService.Migrations.change()
  end
end
