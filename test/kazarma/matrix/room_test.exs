# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.RoomTest do
  use Kazarma.DataCase

  import Kazarma.Matrix.Room

  @ap_user_server "pleroma.interhacker.space"
  @ap_user_name "test_user_bob2"
  @ap_puppet_username "_ap_#{@ap_user_name}___#{@ap_user_server}"
  @ap_puppet_matrix_id "@#{@ap_puppet_username}:kazarma"
  @ap_puppet_matrix_timeline "##{@ap_puppet_username}:kazarma"

  describe "Room search (Synapse asks the application service for a room in its namespace)" do
    @describetag :external

    setup :set_mox_from_context
    setup :verify_on_exit!

    test "if the given room ID corresponds to a puppet timeline for an existing AP user it doesn't create an AP user room" do
      assert :error = query_alias(@ap_puppet_matrix_timeline)
    end

    test "if the alias doesn't correspond to anything it doesn't create the room" do
      assert :error = query_alias("#not-in-namespace:kazarma")
    end

    test "if the AP user doesn't exist it doesn't create the room" do
      assert :error = query_alias("#_ap_nonexisting___pleroma:kazarma")
    end
  end
end
