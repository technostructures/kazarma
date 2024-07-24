# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo.Migrations.RemoveMatrixAppServiceIndexUniqueness do
  use Ecto.Migration

  def change do
    MatrixAppService.Migrations.remove_indexes_uniqueness()
  end
end
