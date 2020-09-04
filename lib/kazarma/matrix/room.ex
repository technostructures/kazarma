defmodule Kazarma.Matrix.Room do
  require Logger

  def query_alias(room_alias) do
    Logger.debug("Received ask for alias #{room_alias}")
  end
end
