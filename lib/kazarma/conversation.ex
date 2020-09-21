defmodule Kazarma.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :ap_id, :string
    field :matrix_id, :string
    field :members, :map

    timestamps()
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:matrix_id, :ap_id, :members])
    |> validate_required([:matrix_id, :ap_id, :members])
    |> unique_constraint(:matrix_id)
    |> unique_constraint(:ap_id)
  end
end
