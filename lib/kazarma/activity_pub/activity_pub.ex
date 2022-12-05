# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub do
  @moduledoc false

  use Kazarma.Config

  defdelegate create(params, pointer \\ nil), to: @activitypub_server
  defdelegate update(params), to: @activitypub_server
  defdelegate follow(follower, followed), to: @activitypub_server
  defdelegate unfollow(follower, followed), to: @activitypub_server
  defdelegate delete(object, local, delete_actor), to: @activitypub_server
  defdelegate accept(params), to: @activitypub_server
end
