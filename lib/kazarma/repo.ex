# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo do
  use Ecto.Repo,
    otp_app: :kazarma,
    adapter: Ecto.Adapters.Postgres
end
