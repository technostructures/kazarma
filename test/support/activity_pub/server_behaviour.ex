defmodule Kazarma.ActivityPub.ServerBehaviour do
  @moduledoc """
  Behaviour used to mock the `ActivityPub` module.
  """

  @callback create(map(), String.t() | nil) :: :ok | any
end
