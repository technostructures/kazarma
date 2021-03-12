defmodule Kazarma.Config do
  defmacro __using__(_) do
    quote do
      @matrix_client Application.get_env(:kazarma, :matrix) |> Keyword.fetch!(:client)
    end
  end
end
