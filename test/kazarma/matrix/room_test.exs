# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.RoomTest do
  use Kazarma.DataCase

  import Mox
  import Kazarma.Matrix.Room

  @ap_user_server "kiwifarms.cc"
  @ap_user_name "test_user_bob2"
  @ap_puppet_username "_ap_#{@ap_user_name}___#{@ap_user_server}"
  @ap_puppet_matrix_id "@#{@ap_puppet_username}:kazarma"
  @ap_puppet_matrix_timeline "##{@ap_puppet_username}:kazarma"

  describe "Room search (Synapse asks the application service for a room in its namespace)" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    test "if the given room ID corresponds to a puppet timeline for an existing AP user it creates the timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:register, 1, fn
        [
          username: @ap_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => @ap_puppet_matrix_id}}
      end)
      |> expect(:create_room, 1, fn
        [
          visibility: :public,
          name: "Bob",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: @ap_puppet_username,
          initial_state: [%{content: %{guest_access: :can_join}, type: "m.room.guest_access"}]
        ],
        [user_id: @ap_puppet_matrix_id] ->
          {:ok, %{"room_id" => "!room_id:kazarma"}}
      end)
      |> expect(:client, 1, fn [user_id: @ap_puppet_matrix_id] ->
        :client_puppet
      end)
      |> expect(:put_displayname, fn
        :client_puppet, @ap_puppet_matrix_id, "Bob" ->
          :ok
      end)

      assert :ok = query_alias(@ap_puppet_matrix_timeline)
    end

    test "if the alias doesn't correspond to anything it doesn't create the room" do
      assert :error = query_alias("#not-in-namespace:kazarma")
    end

    test "if the AP user doesn't exist it doesn't create the room" do
      assert :error = query_alias("#_ap_nonexisting___pleroma:kazarma")
    end
  end
end
