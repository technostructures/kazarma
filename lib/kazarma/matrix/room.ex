defmodule Kazarma.Matrix.Room do
  @behaviour MatrixAppService.Adapter.Room
  require Logger

  @impl MatrixAppService.Adapter.Room
  def query_alias(room_alias) do
    Logger.debug("Received ask for alias #{room_alias}")
  end
end
