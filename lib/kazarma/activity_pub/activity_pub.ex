defmodule Kazarma.ActivityPub do
  @moduledoc false

  use Kazarma.Config

  defdelegate create(params, pointer \\ nil), to: @activitypub_server
  defdelegate update(params), to: @activitypub_server
end
