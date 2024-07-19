# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.UserTest do
  use Kazarma.DataCase

  import Kazarma.Matrix.User
  import Kazarma.MatrixMocks

  # This is an account created on a public ActivityPub instance
  @ap_user_server "pleroma.interhacker.space"
  @ap_user_name "pierre"
  @ap_user_displayname "Pierre"
  @ap_puppet_username "_ap_#{@ap_user_name}___#{@ap_user_server}"
  @ap_puppet_matrix_id "@#{@ap_puppet_username}:kazarma"

  describe "User search (Synapse asks the application service for a user in its namespace)" do
    @describetag :external

    setup :set_mox_from_context
    setup :verify_on_exit!

    test "if the given matrix ID corresponds to a puppet ID for an existing AP user it creates the puppet user" do
      Kazarma.Matrix.TestClient
      |> expect_register(%{
        username: @ap_puppet_username,
        matrix_id: @ap_puppet_matrix_id,
        displayname: @ap_user_displayname
      })

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
