# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ActorTest do
  use KazarmaWeb.ConnCase

  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint KazarmaWeb.Endpoint

  alias Kazarma.Bridge

  describe "when browsing a Matrix user page" do
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

      ActivityPub.Object.do_insert(%{
        data: %{
          "id" => "http://kazarma/-/alice/note/note1",
          "actor" => "http://kazarma/-/alice",
          "type" => "Note",
          "content" => "Note 1",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        }
      })

      ActivityPub.Object.do_insert(%{
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

  describe "when browsing an ActivityPub user page" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      # {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()

      {:ok, actor} =
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

      actor
      |> ActivityPub.Actor.format_remote_actor()
      |> ActivityPub.Actor.set_cache()

      for x <- 1..25 do
        {:ok, inserted_at} = NaiveDateTime.new(2023, 10, 17, 12, 0, x)

        x = if(x < 10, do: "0#{x}", else: "#{x}")

        Kazarma.Repo.insert!(%ActivityPub.Object{
          inserted_at: inserted_at,
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

    test "it shows user info", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pleroma/alice")

      assert html =~ "Alice"
      assert html =~ "@_ap_alice___pleroma:kazarma"
      assert html =~ "@alice@pleroma"
      assert html =~ "This user is not bridged."
    end

    test "it shows paginated public activities if the user is bridged", %{conn: conn} do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, view, html} = live(conn, "/pleroma/alice")

      assert html =~ "Note 25"
      assert html =~ "Note 24"
      assert html =~ "Note 23"
      assert html =~ "Note 22"
      assert html =~ "Note 21"
      assert html =~ "Note 20"
      assert html =~ "Note 19"
      assert html =~ "Note 18"
      assert html =~ "Note 17"
      assert html =~ "Note 16"

      refute html =~ "Note 15"
      refute html =~ "Note 14"
      refute html =~ "Note 13"
      refute html =~ "Note 12"
      refute html =~ "Note 11"
      refute html =~ "Note 10"
      refute html =~ "Note 09"
      refute html =~ "Note 08"
      refute html =~ "Note 07"
      refute html =~ "Note 06"
      refute html =~ "Note 05"
      refute html =~ "Note 04"
      refute html =~ "Note 03"
      refute html =~ "Note 02"
      refute html =~ "Note 01"

      html = view |> element("button", "...") |> render_click()

      assert html =~ "Note 25"
      assert html =~ "Note 24"
      assert html =~ "Note 23"
      assert html =~ "Note 22"
      assert html =~ "Note 21"
      assert html =~ "Note 20"
      assert html =~ "Note 19"
      assert html =~ "Note 18"
      assert html =~ "Note 17"

      assert html =~ "Note 16"
      assert html =~ "Note 15"
      assert html =~ "Note 14"
      assert html =~ "Note 13"
      assert html =~ "Note 12"
      assert html =~ "Note 11"
      assert html =~ "Note 10"
      assert html =~ "Note 09"
      assert html =~ "Note 08"
      assert html =~ "Note 07"
      assert html =~ "Note 06"

      refute html =~ "Note 05"
      refute html =~ "Note 04"
      refute html =~ "Note 03"
      refute html =~ "Note 02"
      refute html =~ "Note 01"

      html = view |> element("button", "...") |> render_click()

      assert html =~ "Note 25"
      assert html =~ "Note 24"
      assert html =~ "Note 23"
      assert html =~ "Note 22"
      assert html =~ "Note 21"
      assert html =~ "Note 20"
      assert html =~ "Note 19"
      assert html =~ "Note 18"
      assert html =~ "Note 17"

      assert html =~ "Note 16"
      assert html =~ "Note 15"
      assert html =~ "Note 14"
      assert html =~ "Note 13"
      assert html =~ "Note 12"
      assert html =~ "Note 11"
      assert html =~ "Note 10"
      assert html =~ "Note 09"
      assert html =~ "Note 08"
      assert html =~ "Note 07"
      assert html =~ "Note 06"

      assert html =~ "Note 05"
      assert html =~ "Note 04"
      assert html =~ "Note 03"
      assert html =~ "Note 02"
      assert html =~ "Note 01"

      refute html =~ "..."
    end
  end

  describe "when searching from a user page" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      # {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()

      {:ok, actor} =
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

      actor
      |> ActivityPub.Actor.format_remote_actor()
      |> ActivityPub.Actor.set_cache()

      :ok
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

    test "it handles 'search' with an error when the user is not found", %{conn: conn} do
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

    test "it shows an error and redirects if the user is not found", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "User not found"}}}} =
               live(conn, "/pleroma/not_found")
    end
  end
end
