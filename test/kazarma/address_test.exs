# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.AddressTest do
  use Kazarma.DataCase

  import Kazarma.Address

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "parse_ap_username/1" do
    test("recognizes correct remote AP addresses") do
      assert parse_ap_username("TeS_t@ex-sample.edu") == {:activity_pub, "TeS_t", "ex-sample.edu"}

      assert parse_ap_username("@teSt@xn--exsampleedu") ==
               {:activity_pub, "teSt", "xn--exsampleedu"}

      assert parse_ap_username("xn--teSt@exsampleedu") ==
               {:activity_pub, "xn--teSt", "exsampleedu"}

      assert parse_ap_username("TeS-t@ex-sample.edu") == {:activity_pub, "TeS-t", "ex-sample.edu"}

      assert parse_ap_username("Te.S-t@ex-sample.edu") ==
               {:activity_pub, "Te.S-t", "ex-sample.edu"}

      assert parse_ap_username("AssoEunomia@mastodon.social") ==
               {:activity_pub, "AssoEunomia", "mastodon.social"}
    end

    test("recognizes correct AP addresses for remote Matrix addresses") do
      assert parse_ap_username("@TeS_t___tes.t@kazarma") == {:remote_matrix, "TeS_t", "tes.t"}
    end

    test("recognizes correct AP addresses for local Matrix addresses") do
      assert parse_ap_username("@TeS_t@kazarma") == {:local_matrix, "TeS_t"}
    end

    test("rejects invalid AP addresses") do
      assert parse_ap_username("-teSt@-exsample.co.uk") == {:error, :invalid_address}
      assert parse_ap_username("@-teSt@-exsample.co.uk") == {:error, :invalid_address}
      assert parse_ap_username("-teSt@-exsampleedu") == {:error, :invalid_address}
      assert parse_ap_username("xn--teSt@-exsampleedu") == {:error, :invalid_address}
    end
  end

  describe "ap_username_to_matrix_id/2" do
    test "remote" do
      assert ap_username_to_matrix_id("TeS_t@ex-sample.edu") ==
               {:ok, "@_ap_tes_t___ex-sample.edu:kazarma"}

      assert ap_username_to_matrix_id("@teSt@xn--exsampleedu") ==
               {:ok, "@_ap_test___xn--exsampleedu:kazarma"}

      assert ap_username_to_matrix_id("xn--teS.t@exsampleedu") ==
               {:ok, "@_ap_xn--tes.t___exsampleedu:kazarma"}

      assert ap_username_to_matrix_id("TeS_t@ex-sample.edu", [:activity_pub]) ==
               {:ok, "@_ap_tes_t___ex-sample.edu:kazarma"}

      assert ap_username_to_matrix_id("TeS_t@ex-sample.edu", [:remote_matrix]) ==
               {:error, :not_found}

      assert ap_username_to_matrix_id("TeS_t@ex-sample.edu", [:local_matrix]) ==
               {:error, :not_found}
    end

    test("recognizes correct AP addresses for remote Matrix addresses") do
      assert ap_username_to_matrix_id("@TeS_t___tes.t@kazarma") == {:ok, "@TeS_t:tes.t"}

      assert ap_username_to_matrix_id("@TeS_t___tes.t@kazarma", [:activity_pub]) ==
               {:error, :not_found}

      assert ap_username_to_matrix_id("@TeS_t___tes.t@kazarma", [:remote_matrix]) ==
               {:ok, "@TeS_t:tes.t"}

      assert ap_username_to_matrix_id("@TeS_t___tes.t@kazarma", [:local_matrix]) ==
               {:error, :not_found}
    end

    test("recognizes correct AP addresses for local Matrix addresses") do
      assert ap_username_to_matrix_id("@TeS_t@kazarma") == {:ok, "@TeS_t:kazarma"}
      assert ap_username_to_matrix_id("@TeS_t@kazarma", [:remote_matrix]) == {:error, :not_found}
      assert ap_username_to_matrix_id("@TeS_t@kazarma", [:remote_matrix]) == {:error, :not_found}

      assert ap_username_to_matrix_id("@TeS_t@kazarma", [:local_matrix]) ==
               {:ok, "@TeS_t:kazarma"}
    end

    test("rejects invalid AP addresses") do
      assert ap_username_to_matrix_id("-teSt@-exsample.co.uk") == {:error, :not_found}
      assert ap_username_to_matrix_id("@-teSt@-exsample.co.uk") == {:error, :not_found}
    end
  end

  describe "parse_matrix_username/1" do
    test("recognizes correct local Matrix addresses") do
      assert parse_matrix_id("tes-t:kazarma") == {:local_matrix, "tes-t"}
      assert parse_matrix_id("_ap_te.s=-t:kazarma") == {:local_matrix, "_ap_te.s=-t"}
    end

    test("recognizes correct remote Matrix addresses") do
      assert parse_matrix_id("tes=a.t:ex-sample.edu") ==
               {:remote_matrix, "tes=a.t", "ex-sample.edu"}

      assert parse_matrix_id("tes=a.t:ex-sample.edu") ==
               {:remote_matrix, "tes=a.t", "ex-sample.edu"}

      assert parse_matrix_id("tesa.t:ex-sample.edu") ==
               {:remote_matrix, "tesa.t", "ex-sample.edu"}

      assert parse_matrix_id("@tesa.t:ex-sample.edu") ==
               {:remote_matrix, "tesa.t", "ex-sample.edu"}

      assert parse_matrix_id("tes=-t:ex-sample.edu") ==
               {:remote_matrix, "tes=-t", "ex-sample.edu"}

      assert parse_matrix_id("te.s=-t:ex-sample.edu") ==
               {:remote_matrix, "te.s=-t", "ex-sample.edu"}

      assert parse_matrix_id("@t_e/s-a.t:ex-sample.edu") ==
               {:remote_matrix, "t_e/s-a.t", "ex-sample.edu"}

      assert parse_matrix_id("22tes=t:ex-sample.edu") ==
               {:remote_matrix, "22tes=t", "ex-sample.edu"}

      assert parse_matrix_id("tes22t:ex-sample.co.uk") ==
               {:remote_matrix, "tes22t", "ex-sample.co.uk"}

      assert parse_matrix_id("@2-test:ex-sample.co.uk") ==
               {:remote_matrix, "2-test", "ex-sample.co.uk"}
    end

    test("recognizes correct puppet Matrix addresses") do
      assert parse_matrix_id("_ap_te___sa.t:kazarma") == {:activity_pub, "te", "sa.t"}
    end

    test("rejects invalid Matrix addresses") do
      assert parse_matrix_id("TeS=-a.t:ex-sample.edu") == {:error, :invalid_address}
      assert parse_matrix_id("@-teSt:-exsample.co.uk") == {:error, :invalid_address}
      assert parse_matrix_id("Te.S=-t:ex-sample.edu") == {:error, :invalid_address}
      assert parse_matrix_id("@-teSt:-exsample.co.uk") == {:error, :invalid_address}
      assert parse_matrix_id("@test:-exsample.co.uk") == {:error, :invalid_address}
      assert parse_matrix_id("-teSt:-exsample.co.uk") == {:error, :invalid_address}
      assert parse_matrix_id("@teSt@exsample.co.uk") == {:error, :invalid_address}
      assert parse_matrix_id("teSt@exsample.co.uk") == {:error, :invalid_address}
      assert parse_matrix_id("TeS=-t:ex-sample.edu") == {:error, :invalid_address}
      assert parse_matrix_id("-tes22t:-exsample.co.uk") == {:error, :invalid_address}
      assert parse_matrix_id("-teSt:-exsample.co.uk") == {:error, :invalid_address}
    end
  end

  describe "matrix_id_to_ap_username/1" do
    test("recognizes correct local Matrix addresses") do
      assert matrix_id_to_ap_username("tes-t:kazarma") == {:ok, "tes-t@kazarma"}
      assert matrix_id_to_ap_username("_ap_te.s=-t:kazarma") == {:ok, "_ap_te.s=-t@kazarma"}

      assert matrix_id_to_ap_username("test=test:kazarma", [:activity_pub]) ==
               {:error, :not_found}

      assert matrix_id_to_ap_username("test=test:kazarma", [:local_matrix]) ==
               {:ok, "test=test@kazarma"}

      assert matrix_id_to_ap_username("test=test:kazarma", [:remote_matrix]) ==
               {:error, :not_found}
    end

    test("recognizes correct remote Matrix addresses") do
      assert matrix_id_to_ap_username("tes=a.t:ex-sample.edu") ==
               {:ok, "tes=a.t___ex-sample.edu@kazarma"}

      assert matrix_id_to_ap_username("tes=a.t:ex-sample.edu") ==
               {:ok, "tes=a.t___ex-sample.edu@kazarma"}

      assert matrix_id_to_ap_username("@tesa.t:ex-sample.edu") ==
               {:ok, "tesa.t___ex-sample.edu@kazarma"}

      assert matrix_id_to_ap_username("@tesa.t:ex-sample.edu", [:activity_pub]) ==
               {:error, :not_found}

      assert matrix_id_to_ap_username("@tesa.t:ex-sample.edu", [:local_matrix]) ==
               {:error, :not_found}

      assert matrix_id_to_ap_username("@tesa.t:ex-sample.edu", [:remote_matrix]) ==
               {:ok, "tesa.t___ex-sample.edu@kazarma"}
    end

    test("recognizes correct puppet Matrix addresses") do
      assert matrix_id_to_ap_username("_ap_te___sa.t:kazarma") == {:ok, "te@sa.t"}

      assert matrix_id_to_ap_username("_ap_te___sa.t:kazarma", [:activity_pub]) ==
               {:ok, "te@sa.t"}

      assert matrix_id_to_ap_username("_ap_te___sa.t:kazarma", [:local_matrix]) ==
               {:error, :not_found}

      assert matrix_id_to_ap_username("_ap_te___sa.t:kazarma", [:remote_matrix]) ==
               {:error, :not_found}
    end

    test("rejects invalid Matrix addresses") do
      assert matrix_id_to_ap_username("TeS=-a.t:ex-sample.edu") == {:error, :not_found}
      assert matrix_id_to_ap_username("@-teSt:-exsample.co.uk") == {:error, :not_found}
      assert matrix_id_to_ap_username("@test:-exsample.co.uk") == {:error, :not_found}
      assert matrix_id_to_ap_username("teSt@exsample.co.uk") == {:error, :not_found}
      assert matrix_id_to_ap_username("TeS=-t:ex-sample.edu") == {:error, :not_found}
      assert matrix_id_to_ap_username("-tes22t:-exsample.co.uk") == {:error, :not_found}
      assert matrix_id_to_ap_username("-teSt:-exsample.co.uk") == {:error, :not_found}
    end
  end

  test "get_username_localpart" do
    assert get_username_localpart("test") == "test"
    assert get_username_localpart("@test") == "test"
    assert get_username_localpart("@test@#{domain()}") == "test"
    # only works with kazarma ?
    assert get_username_localpart("@test@server.org") == "test@server.org"
  end

  test "ap_localpart_to_local_ap_id" do
    assert ap_localpart_to_local_ap_id("test") == "http://#{domain()}/-/test"
    assert ap_localpart_to_local_ap_id("te-s_T.2") == "http://#{domain()}/-/te-s_T.2"
  end

  describe "matrix_id_to_actor" do
    setup do
      {:ok, actor} =
        ActivityPub.Object.insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Alice",
            "preferredUsername" => "alice",
            "url" => "http://pleroma/pub/actors/alice",
            "id" => "http://pleroma/pub/actors/alice",
            "username" => "alice@pleroma"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://pleroma/pub/actors/alice"
        })

      {:ok, actor: actor}
    end

    test "search users" do
      assert matrix_id_to_actor("test") == {:error, :not_found}
      assert matrix_id_to_actor("alice") == {:error, :not_found}
    end
  end
end
