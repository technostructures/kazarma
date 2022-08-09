# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub do
  @moduledoc false

  use Kazarma.Config

  defdelegate create(params, pointer \\ nil), to: @activitypub_server
  defdelegate update(params), to: @activitypub_server
  defdelegate follow(follower, followed), to: @activitypub_server
end
