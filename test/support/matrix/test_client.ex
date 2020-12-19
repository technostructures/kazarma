defmodule Kazarma.Matrix.TestClient do
  require Logger

  def client(), do: nil

  def get_profile(_, "@existing:kazarma"), do: {:ok, %{"displayname" => "displayname"}}
  def get_profile(_, _), do: {:error, :not_found}
end
