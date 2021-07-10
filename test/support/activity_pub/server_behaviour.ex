defmodule Kazarma.ActivityPub.ServerBehaviour do
  @moduledoc """
  Behaviour used to mock the `ActivityPub` module.
  """

  @callback create(map(), String.t() | nil) :: {:ok, any()} | {:error, any()}
  @callback update(map()) :: {:ok, any()} | {:error, any()}
end
