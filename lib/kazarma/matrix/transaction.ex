defmodule Kazarma.Matrix.Transaction do
  @behaviour MatrixAppService.TransactionModule
  require Logger

  @impl MatrixAppService.TransactionModule
  def new_event(%MatrixAppService.Event{
        type: "m.room.create",
        content: %{"creator" => creator_id}
      }) do
    Logger.debug("Room creation by #{creator_id}")
  end

  def new_event(%MatrixAppService.Event{
        type: "m.room.name",
        content: %{"name" => name}
      }) do
    Logger.debug("Attributing name #{name}")
  end

  def new_event(%MatrixAppService.Event{type: type}) do
    Logger.debug("Received #{type} from Synapse")
  end
end
