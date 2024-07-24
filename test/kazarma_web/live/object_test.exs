# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ObjectTest do
  use KazarmaWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint KazarmaWeb.Endpoint

  alias Kazarma.Bridge

  describe "object page" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

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
        public: true,
        local: true,
        data: %{
          "id" => "http://kazarma/-/alice/note/grand_parent",
          "actor" => "http://kazarma/-/alice",
          "type" => "Note",
          "content" => "Grand parent",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        }
      })

      ActivityPub.Object.do_insert(%{
        public: true,
        local: true,
        data: %{
          "id" => "http://kazarma/-/alice/note/parent",
          "actor" => "http://kazarma/-/alice",
          "type" => "Note",
          "content" => "Parent",
          "inReplyTo" => "http://kazarma/-/alice/note/grand_parent",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        }
      })

      {:ok, local_note} =
        ActivityPub.Object.do_insert(%{
          public: true,
          local: true,
          data: %{
            "id" => "http://kazarma/-/alice/note/note1",
            "actor" => "http://kazarma/-/alice",
            "type" => "Note",
            "content" => "Note 1",
            "inReplyTo" => "http://kazarma/-/alice/note/parent",
            "to" => ["https://www.w3.org/ns/activitystreams#Public"]
          }
        })

      ActivityPub.Object.do_insert(%{
        public: true,
        local: true,
        data: %{
          "id" => "http://kazarma/-/alice/note/reply1",
          "actor" => "http://kazarma/-/alice",
          "type" => "Note",
          "content" => "Reply 1",
          "inReplyTo" => "http://kazarma/-/alice/note/note1",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        }
      })

      ActivityPub.Object.do_insert(%{
        public: true,
        local: true,
        data: %{
          "id" => "http://kazarma/-/alice/note/reply2",
          "actor" => "http://kazarma/-/alice",
          "type" => "Note",
          "content" => "Reply 2",
          "inReplyTo" => "http://kazarma/-/alice/note/note1",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        }
      })

      {:ok, _actor} =
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

      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://pleroma/pub/actors/bob",
            "id" => "http://pleroma/pub/actors/bob",
            "username" => "bob@pleroma"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://pleroma/pub/actors/bob"
        })

      actor
      |> ActivityPub.Actor.format_remote_actor()
      |> ActivityPub.Actor.set_cache()

      {:ok, remote_note} =
        ActivityPub.Object.do_insert(%{
          public: true,
          local: false,
          data: %{
            "id" => "http://pleroma/pub/objects/note2",
            "actor" => "http://pleroma/pub/actors/alice",
            "type" => "Note",
            "content" => "Note 2",
            "to" => ["https://www.w3.org/ns/activitystreams#Public"]
          }
        })

      {:ok, local_note: local_note, remote_note: remote_note}
    end

    test "it displays local note with context", %{conn: conn, local_note: local_note} do
      {:ok, _view, html} = live(conn, "/-/alice/note/#{local_note.id}")

      assert html =~ "Grand parent"
      assert html =~ "Parent"
      assert html =~ "Note 1"
      assert html =~ "Reply 1"
      assert html =~ "Reply 2"
    end

    test "it redirects when given a bad uuid", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "Activity not found"}}}} =
               live(conn, "/-/alice/note/asdf")
    end

    test "it redirects to original URL for remote activities", %{
      conn: conn,
      remote_note: remote_note
    } do
      assert {:error, {:redirect, %{flash: %{}, to: "http://pleroma/pub/objects/note2"}}} =
               live(conn, "/pleroma/alice/note/#{remote_note.id}")
    end

    test "it does not redirect to remote activity if coming from live navigation", %{
      conn: conn,
      local_note: local_note,
      remote_note: remote_note
    } do
      {:ok, view, _html} = live(conn, "/-/alice/note/#{local_note.id}")

      {:ok, _view, html} =
        live_redirect(view, to: "http://kazarma/pleroma/alice/note/#{remote_note.id}")

      assert html =~ "Note 2"
    end

    test "it handles 'search' events with a redirect when the user exist", %{
      conn: conn,
      local_note: local_note
    } do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, view, _html} = live(conn, "/-/alice/note/#{local_note.id}")

      view
      |> render_hook(:search, %{"search" => %{"address" => "http://pleroma/pub/actors/alice"}})

      assert_receive {_, {:redirect, _, %{kind: :push, to: "/pleroma/alice"}}}
    end

    test "it handles 'search'  with an error when the user is not found", %{
      conn: conn,
      local_note: local_note
    } do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, view, _html} = live(conn, "/-/alice/note/#{local_note.id}")

      view
      |> render_hook(:search, %{"search" => %{"address" => "http://pleroma/pub/actors/bob"}})

      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "User not found"}}}} =
               live(conn, "/pleroma/not_found")
    end
  end
end
