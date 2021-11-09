# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.UserTest do
  use Kazarma.DataCase

  import Mox
  import Kazarma.Matrix.User

  describe "User search" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    test "hey" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 1, fn [user_id: "@ap_test_user_bob1=blob.cat:kazarma"] ->
        :client_puppet
      end)
      |> expect(:register, 2, fn
        [
          username: "ap_test_user_bob1=blob.cat",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => "@ap_test_user_bob1=blob.cat:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        :client_puppet, "@ap_test_user_bob1=blob.cat:kazarma", "Bob" ->
          :ok
      end)

      assert :ok = query_user("@ap_test_user_bob1=blob.cat:kazarma")
    end

    test "hey3" do
      assert :error = query_user("@ap_nonexisting=pleroma:kazarma")
    end

    test "hey2" do
      assert :error = query_user("@local_user:kazarma")
    end
  end
end
