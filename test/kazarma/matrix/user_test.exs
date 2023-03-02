# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.UserTest do
  use Kazarma.DataCase

  import Kazarma.Matrix.User

  # This is an account created on a public ActivityPub instance
  @ap_user_server "pleroma.interhacker.space"
  @ap_user_name "test_user_bob2"
  @ap_puppet_username "_ap_#{@ap_user_name}___#{@ap_user_server}"
  @ap_puppet_matrix_id "@#{@ap_puppet_username}:kazarma"

  describe "User search (Synapse asks the application service for a user in its namespace)" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    test "if the given matrix ID corresponds to a puppet ID for an existing AP user it creates the puppet user" do
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
      |> expect(:put_displayname, fn
        @ap_puppet_matrix_id, "Bob", user_id: @ap_puppet_matrix_id ->
          :ok
      end)

      assert :ok = query_user(@ap_puppet_matrix_id)
    end

    test "if the AP user doesn't exist it returns an error" do
      assert :error = query_user("@_ap_nonexisting___pleroma:kazarma")
    end

    test "if the address is not in puppet format it returns an error" do
      assert :error = query_user("@local_user:kazarma")
    end
  end
end
