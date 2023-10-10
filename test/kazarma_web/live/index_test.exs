# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.IndexTest do
  use KazarmaWeb.ConnCase

  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint KazarmaWeb.Endpoint

  alias Kazarma.Bridge

  describe "search" do
    setup :set_mox_from_context
    setup :verify_on_exit!

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

      actor
      |> ActivityPub.Actor.format_remote_actor()
      |> ActivityPub.Actor.set_cache()

      :ok
    end

    defmacro assert_search_redirects(address, path) do
      quote do
        {:ok, view, html} = live(var!(conn), "/")

        view
        |> form("#search", search: %{address: unquote(address)})
        |> render_submit()

        assert_redirect(view, unquote(path))
      end
    end

    test "can search for local Matrix user", %{conn: conn} do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@alice:kazarma" ->
        {:ok, %{"displayname" => "Alice"}}
      end)

      assert_search_redirects("@alice:kazarma", "/-/alice")
    end

    test "can search for remote Matrix user", %{conn: conn} do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@alice:matrix" ->
        {:ok, %{"displayname" => "Alice"}}
      end)

      # @TODO: is this really nice?
      assert_search_redirects("@alice:matrix", "/-/alice___matrix")
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
end
