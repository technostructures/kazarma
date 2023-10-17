# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ActorTest do
  use KazarmaWeb.ConnCase

  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint KazarmaWeb.Endpoint

  alias Kazarma.Bridge

  describe "displaying a Matrix user page" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()

      {:ok, _user} =
        Bridge.create_user(%{
          local_id: "@alice:kazarma",
          remote_id: "http://kazarma/-/alice",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/-/alice",
              "preferredUsername" => "alice",
              "name" => "Alice",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/avatar"}
            },
            "keys" => keys
          }
        })

      ActivityPub.Object.insert(%{
        data: %{
          "id" => "http://kazarma/-/alice/note/note1",
          "actor" => "http://kazarma/-/alice",
          "type" => "Note",
          "content" => "Note 1",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        }
      })

      ActivityPub.Object.insert(%{
        data: %{
          "id" => "http://kazarma/-/alice/note/note2",
          "actor" => "http://kazarma/-/alice",
          "type" => "Note",
          "content" => "Note 2",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        }
      })

      :ok
    end

    test "it shows user info", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/-/alice")

      assert html =~ "Alice"
      assert html =~ "@alice:kazarma"
      assert html =~ "@alice@kazarma"
      assert html =~ "This user is not bridged."
    end

    test "it shows user public activities if the user is bridged", %{conn: conn} do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "matrix_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://kazarma/-/alice"
        })

      {:ok, _view, html} = live(conn, "/-/alice")

      assert html =~ "Note 1"
      assert html =~ "Note 2"
    end

    test "it gets the user from Matrix if it's not in database", %{conn: conn} do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      {:ok, _view, html} = live(conn, "/-/bob")

      assert html =~ "Bob"
      assert html =~ "@bob:kazarma"
      assert html =~ "@bob@kazarma"
      assert html =~ "This user is not bridged."
    end

    test "it shows an error and redirects if the user is not found", %{conn: conn} do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@not_found:kazarma" ->
        {:error, :not_found}
      end)

      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "User not found"}}}} =
               live(conn, "/-/not_found")
    end
  end

  describe "displaying an ActivityPub user page" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      # {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()

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

      for x <- 1..25 do
        ActivityPub.Object.insert(%{
          data: %{
            "id" => "http://kazarma/-/alice/note/note#{x}",
            "actor" => "http://pleroma/pub/actors/alice",
            "type" => "Note",
            "content" => "Note #{x}",
            "to" => ["https://www.w3.org/ns/activitystreams#Public"]
          }
        })
      end

      :ok
    end

    test "shows user info", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pleroma/alice")

      assert html =~ "Alice"
      assert html =~ "@_ap_alice___pleroma:kazarma"
      assert html =~ "@alice@pleroma"
      assert html =~ "This user is not bridged."
    end

    test "shows user public activities if the user is bridged", %{conn: conn} do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, _view, html} = live(conn, "/pleroma/alice")

      html
      |> assert_html_include("div[id=\"http://kazarma/-/alice/note/note1\"")
      |> assert_html_include("div[id=\"http://kazarma/-/alice/note/note2\"")
      |> assert_html_include("div[id=\"http://kazarma/-/alice/note/note11\"", 0)

      # Todo: add test to ensure just tens activities are displaied
    end

    test "handles 'load_more' events", %{conn: conn} do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, view, html} = live(conn, "/pleroma/alice")

      view
      |> render_hook(:load_more)

      view
      |> render_hook(:load_more)

      html = render(view)

      html
      |> assert_html_include("div[id=\"http://kazarma/-/alice/note/note4\"")
      |> assert_html_include("div[id=\"http://kazarma/-/alice/note/note14\"")
      |> assert_html_include("div[id=\"http://kazarma/-/alice/note/note24\"")
      |> assert_html_include("div[id=\"http://kazarma/-/alice/note/note35\"", 0)
      |> refute_html_include("button", %{}, "load more")
    end

    test "handles 'search' events with a redirect when the user exist", %{conn: conn} do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, view, html} = live(conn, "/pleroma/alice")

      view
      |> render_hook(:search, %{"search" => %{"address" => "http://pleroma/pub/actors/alice"}})

      assert_receive {_, {:redirect, _, %{kind: :push, to: "/pleroma/alice"}}}
    end

    test "handles 'search'  with an error when the user is not found", %{conn: conn} do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, view, html} = live(conn, "/pleroma/alice")

      view
      |> render_hook(:search, %{"search" => %{"address" => "http://pleroma/pub/actors/bob"}})

      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "User not found"}}}} =
               live(conn, "/pleroma/not_found")
    end

    test "shows an error and redirects if the user is not found", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "User not found"}}}} =
               live(conn, "/pleroma/not_found")
    end
  end
end
