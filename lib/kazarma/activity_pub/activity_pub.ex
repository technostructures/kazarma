# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub do
  @moduledoc false

  use Kazarma.Config

  defdelegate create(params), to: @activitypub_server
  defdelegate update(params), to: @activitypub_server
  defdelegate follow(params), to: @activitypub_server
  defdelegate unfollow(params), to: @activitypub_server
  defdelegate delete(object, local, delete_actor), to: @activitypub_server
  defdelegate accept(params), to: @activitypub_server
end
