# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Repo.Migrations.UpdateRoomTypes do
  use Ecto.Migration

  import Ecto.Query

  defp update_room_type(old, new) do
    from(room in MatrixAppService.Bridge.Room,
      where: fragment("(?)->>'type' = ?", room.data, ^old),
      update: [set: [data: fragment("jsonb_set(?, '{type}', ?)", room.data, ^new)]]
    )
    |> Kazarma.Repo.update_all([])
  end

  def change do
    update_room_type("outbox", "actor_outbox")
    update_room_type("chat_message", "chat")
    update_room_type("note", "direct_message")
  end
end
