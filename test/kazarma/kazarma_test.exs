# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.KazarmaTest do
  @moduledoc """
  This module tests the 2 modes of kazarma, by looking up Matrix and ActivityPub users.
  """
  use Kazarma.DataCase, async: false

  import Kazarma.MatrixMocks

  # setup :set_mox_from_context
  # setup :verify_on_exit!

  setup do
    create_local_matrix_user_carole()
    create_remote_matrix_user_david()
    create_ap_user_alice()
    create_unknown_ap_user_erin()

    :ok
  end

  describe "Search in private bridge" do
    test "local Matrix users can be found" do
      # carole

      assert %{ap_id: "http://kazarma/-/carole"} = Kazarma.search_user("@carole:kazarma")
      assert %{ap_id: "http://kazarma/-/carole"} = Kazarma.search_user("http://kazarma/-/carole")
    end

    test "local unknown Matrix users are looked up" do
      # carole2

      Kazarma.Matrix.TestClient
      |> expect_get_profile("@carole2:kazarma", %{"displayname" => "Carole2"})

      assert %{ap_id: "http://kazarma/-/carole2"} = Kazarma.search_user("@carole2:kazarma")

      assert %{ap_id: "http://kazarma/-/carole2"} =
               Kazarma.search_user("http://kazarma/-/carole2")
    end

    test "remote Matrix users can not be found" do
      # franck

      assert nil == Kazarma.search_user("@franck:matrix.org")
      assert nil == Kazarma.search_user("http://kazarma/matrix.org/franck")
    end

    test "opted in AP user can be found" do
      # alice

      assert %{ap_id: "http://pleroma.com/pub/actors/alice"} =
               Kazarma.search_user("@alice.pleroma.com:kazarma")

      assert %{ap_id: "http://pleroma.com/pub/actors/alice"} =
               Kazarma.search_user("http://pleroma.com/pub/actors/alice")
    end

    test "any AP user can be found" do
      # erin

      Kazarma.Matrix.TestClient
      |> expect_get_profile_not_found("@erin.pleroma.com:kazarma")
      |> expect_register(%{
        username: "erin.pleroma.com",
        matrix_id: "@erin.pleroma.com:kazarma",
        displayname: "Erin"
      })

      assert %{ap_id: "http://pleroma.com/pub/actors/erin"} =
               Kazarma.search_user("@erin.pleroma.com:kazarma")

      assert %{ap_id: "http://pleroma.com/pub/actors/erin"} =
               Kazarma.search_user("http://pleroma.com/pub/actors/erin")
    end
  end

  describe "Search in public bridge" do
    setup :config_public_bridge

    test "local Matrix users can not be found" do
      # carole
      # they should not exist anyway

      assert nil == Kazarma.search_user("@local:kazarma")
      assert nil == Kazarma.search_user("http://kazarma/-/local")
    end

    test "local unknown Matrix users are not looked up" do
      # carole2

      assert nil == Kazarma.search_user("@carole2:kazarma")
      assert nil == Kazarma.search_user("http://kazarma/-/carole2")
    end

    test "remote Matrix users can be found" do
      # david

      assert %{ap_id: "http://kazarma/matrix.org/david"} =
               Kazarma.search_user("@david:matrix.org")

      assert %{ap_id: "http://kazarma/matrix.org/david"} =
               Kazarma.search_user("http://kazarma/matrix.org/david")
    end

    test "remote unknown Matrix users are looked up" do
      # david2

      Kazarma.Matrix.TestClient
      |> expect_get_profile("@david2:kazarma", %{"displayname" => "David2"})

      assert %{ap_id: "http://kazarma/matrix.org/david"} =
               Kazarma.search_user("@david:matrix.org")

      assert %{ap_id: "http://kazarma/matrix.org/david"} =
               Kazarma.search_user("http://kazarma/matrix.org/david")
    end

    test "opted in AP user can be found" do
      # alice

      assert %{ap_id: "http://pleroma.com/pub/actors/alice"} =
               Kazarma.search_user("@alice.pleroma.com:kazarma")

      assert %{ap_id: "http://pleroma.com/pub/actors/alice"} =
               Kazarma.search_user("http://pleroma.com/pub/actors/alice")
    end

    test "non opted in AP user can not be found" do
      # erin

      Kazarma.Matrix.TestClient
      |> expect_get_profile_not_found("@erin.pleroma.com:kazarma")

      assert nil == Kazarma.search_user("@erin.pleroma.com:kazarma")
      assert nil == Kazarma.search_user("http://pleroma.com/pub/actors/erin")
    end
  end
end
