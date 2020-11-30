defmodule Kazarma.Repo.Migrations.InitPointers do
  use Ecto.Migration

  def up(), do: inits(:up)
  def down(), do: inits(:down)

  defp inits(dir) do
    # this one is optional but recommended
    Pointers.Migration.init_pointers_ulid_extra()
    # this one is not optional
    Pointers.Migration.init_pointers(dir)
  end
end
