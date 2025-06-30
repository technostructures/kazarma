# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.IndexTest do
  use KazarmaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Kazarma.MatrixMocks
  @endpoint KazarmaWeb.Endpoint

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    {:ok, ap_actor} =
      ActivityPub.Object.do_insert(%{
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

    ap_actor
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    {:ok, _user} =
      Kazarma.Bridge.create_user(%{
        local_id: "@alice.pleroma:kazarma",
        remote_id: "http://pleroma/pub/actors/alice"
      })

    {:ok, local_actor} =
      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Person",
          "name" => "Alice",
          "preferredUsername" => "alice",
          "url" => "http://kazarma/-/alice",
          "id" => "http://kazarma/-/alice",
          "username" => "alice@kazarma"
        },
        "local" => true,
        "public" => true,
        "actor" => "http://kazarma/-/alice"
      })

    local_actor
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    # {:ok, _user} =
    #   Kazarma.Bridge.create_user(%{
    #     local_id: "@alice:kazarma",
    #     remote_id: "http://kazarma/-/alice"
    #   })

    :ok
  end

  defmacro assert_search_redirects(address, path) do
    quote do
      {:ok, view, html} = live(var!(conn), "/")

      view
      |> form("#search-form", search: %{address: unquote(address)})
      |> render_submit()

      assert_redirect(view, unquote(path))
    end
  end

  describe "private bridge" do
    test "can search for local Matrix user", %{conn: conn} do
      Kazarma.Matrix.TestClient
      |> expect_get_profile("@alice:kazarma", %{"displayname" => "Alice"})

      assert_search_redirects("@alice:kazarma", "/-/alice")
    end

    test "can search for remote AP user", %{conn: conn} do
      assert_search_redirects("@alice@pleroma", "/pleroma/alice")
    end

    test "can search for remote AP user without leading @", %{conn: conn} do
      assert_search_redirects("alice@pleroma", "/pleroma/alice")
    end

    test "can search for remote AP user using AP ID", %{conn: conn} do
      assert_search_redirects("http://pleroma/pub/actors/alice", "/pleroma/alice")
    end
  end

  describe "public bridge" do
    setup :config_public_bridge

    test "can search for remote Matrix user", %{conn: conn} do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@alice:matrix" ->
        {:ok, %{"displayname" => "Alice"}}
      end)

      assert_search_redirects("@alice:matrix", "/matrix/alice")
    end
  end
end
