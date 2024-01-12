# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.CollectionTest do
  @moduledoc false

  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter

  describe "activity handler (handle_activity/1) for Invite activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def invite_fixture do
      %ActivityPub.Object{
        data: %{
          "actor" => "http://mobilizon/@alice",
          "cc" => ["http://mobilizon/@group"],
          "id" => "http://mobilizon/member/member",
          "object" => "http://mobilizon/@group",
          "target" => "http://kazarma/-/bob",
          "to" => ["http://kazarma/-/bob"],
          "type" => "Invite"
        }
      }
    end

    def accept_invite_fixture do
      %MatrixAppService.Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "join"},
        sender: "@bob:kazarma",
        room_id: "!room:kazarma",
        state_key: "@bob:kazarma",
        unsigned: %{
          "prev_content" => %{"membership" => "invite"},
          "replaces_state" => "!invite_event"
        }
      }
    end

    setup do
      {:ok, actor} =
        {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://kazarma/-/bob",
            "id" => "http://kazarma/-/bob",
            "username" => "bob@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
        })

      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Group",
          "name" => "Group",
          "preferredUsername" => "group",
          "url" => "http://mobilizon/@group",
          "id" => "http://mobilizon/@group",
          "username" => "group",
          "members" => "http://mobilizon/@group/members",
          "endpoints" => %{"members" => "http://mobilizon/@group/members"}
        },
        "local" => false,
        "actor" => "http://mobilizon/@group",
        "username" => "group"
      })

      {:ok, actor: actor}
    end

    test "when receiving a Invite activity for a Matrix user it invites them to the collection room" do
      Kazarma.Matrix.TestClient
      |> expect(:create_room, fn
        [
          visibility: :private,
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          name: "Group"
        ],
        [user_id: "@_ap_group___mobilizon:kazarma"] ->
          {:ok, %{"room_id" => "!room:kazarma"}}
      end)
      |> expect(:send_state_event, fn
        "!room:kazarma",
        "m.room.member",
        "@bob:kazarma",
        %{"membership" => "invite"},
        [user_id: "@_ap_group___mobilizon:kazarma"] ->
          {:ok, "!invite_event"}
      end)

      assert :ok == handle_activity(invite_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{"type" => "collection"},
                 local_id: "!room:kazarma",
                 remote_id: "http://mobilizon/@group"
               }
             ] = Bridge.list_rooms()

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "!invite_event",
                 remote_id: "http://mobilizon/member/member",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when the user accepts the invitation it sends an Accept/Invite activity" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %{
            data: %{
              "id" => "http://kazarma/-/bob"
            },
            local: true,
            ap_id: "http://kazarma/-/bob",
            username: "bob@kazarma"
          },
          object: "http://mobilizon/member/member",
          to: ["http://mobilizon/@group/members"]
        } ->
          :ok
      end)

      %{
        data: %{"type" => "collection"},
        local_id: "!room:kazarma",
        remote_id: "http://mobilizon/@group"
      }
      |> Bridge.create_room()

      %{
        local_id: "!invite_event",
        remote_id: "http://mobilizon/member/member",
        room_id: "!room:kazarma"
      }
      |> Bridge.create_event()

      assert :ok == Kazarma.Matrix.Transaction.new_event(accept_invite_fixture())
    end
  end

  describe "activity handler (handle_activity/1) for Remove/Invite activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def remove_invite_fixture do
      %ActivityPub.Object{
        data: %{
          "type" => "Remove",
          "actor" => "http://mobilizon/@alice",
          "object" => %{
            data: %{
              "type" => "Invite",
              "target" => "http://kazarma/-/bob",
              "object" => "http://mobilizon/@group"
            }
          },
          "to" => ["http://kazarma/-/bob", "http://mobilizon/@group/members"]
        }
      }
    end

    setup do
      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://kazarma/-/bob",
            "id" => "http://kazarma/-/bob",
            "username" => "bob@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
        })

      {:ok, actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Group",
            "name" => "Group",
            "preferredUsername" => "group",
            "url" => "http://mobilizon/@group",
            "id" => "http://mobilizon/@group",
            "username" => "group",
            "endpoints" => %{"members" => "http://mobilizon/@group/members"}
          },
          "local" => false,
          "actor" => "http://mobilizon/@group",
          "username" => "group"
        })

      {:ok, actor: actor}
    end

    test "when receiving a Remove/Invite activity for a Matrix user in a collection room it kicks them" do
      Kazarma.Matrix.TestClient
      |> expect(:send_state_event, fn
        "!room:kazarma",
        "m.room.member",
        "@bob:kazarma",
        %{"membership" => "leave"},
        [user_id: "@_ap_group___mobilizon:kazarma"] ->
          {:ok, "!invite_event"}
      end)

      %{
        data: %{"type" => "collection"},
        local_id: "!room:kazarma",
        remote_id: "http://mobilizon/@group"
      }
      |> Bridge.create_room()

      assert :ok == handle_activity(remove_invite_fixture())
    end
  end

  describe "activity handler (handle_activity/1) for Note activity in collection" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def note_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://mobilizon/@alice",
          "to" => ["http://mobilizon/@group/members"]
        },
        object: %ActivityPub.Object{
          data: %{
            "id" => "note_id",
            "attributedTo" => "http://mobilizon/@group",
            "type" => "Note",
            "actor" => "http://mobilizon/@alice",
            "content" => "hello",
            "to" => ["http://mobilizon/@group/members"]
          }
        }
      }
    end

    def note_with_reply_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://mobilizon/@alice",
          "to" => ["http://mobilizon/@group/members"]
        },
        object: %ActivityPub.Object{
          data: %{
            "id" => "note_id",
            "attributedTo" => "http://mobilizon/@group",
            "type" => "Note",
            "actor" => "http://mobilizon/@alice",
            "content" => "hello",
            "to" => ["http://mobilizon/@group/members"],
            "inReplyTo" => "http://mobilizon/@group/c/comment"
          }
        }
      }
    end

    setup do
      %{
        data: %{"type" => "collection"},
        local_id: "!room:kazarma",
        remote_id: "http://mobilizon/@group"
      }
      |> Bridge.create_room()

      {:ok, _group} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Group",
            "name" => "Group",
            "preferredUsername" => "group",
            "url" => "http://mobilizon/@group",
            "id" => "http://mobilizon/@group",
            "username" => "group",
            "endpoints" => %{"members" => "http://mobilizon/@group/members"}
          },
          "local" => false,
          "actor" => "http://mobilizon/@group",
          "username" => "group"
        })

      {:ok, _alice} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Alice",
            "preferredUsername" => "alice",
            "url" => "http://mobilizon/@alice",
            "id" => "http://mobilizon/@alice",
            "username" => "alice"
          },
          "local" => false,
          "actor" => "http://mobilizon/@alice",
          "username" => "alice"
        })

      :ok
    end

    test "when receiving a Note activity creating a discussion it forwards the message" do
      Kazarma.Matrix.TestClient
      |> expect(:get_state, fn
        "!room:kazarma",
        "m.room.member",
        "@_ap_alice___mobilizon:kazarma",
        [user_id: "@_ap_group___mobilizon:kazarma"] ->
          %{"membership" => "join"}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{
          "body" => "hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "hello",
          "msgtype" => "m.text"
        },
        [user_id: "@_ap_alice___mobilizon:kazarma"] ->
          {:ok, "event_id"}
      end)

      assert :ok = handle_activity(note_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a Note activity continuing a discussion it forwards as a message with reply" do
      Kazarma.Matrix.TestClient
      |> expect(:get_state, fn
        "!room:kazarma",
        "m.room.member",
        "@_ap_alice___mobilizon:kazarma",
        [user_id: "@_ap_group___mobilizon:kazarma"] ->
          %{"membership" => "join"}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{
          "body" => "hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "hello",
          "msgtype" => "m.text",
          "m.relates_to" => %{"m.in_reply_to" => %{"event_id" => "reply_to_id"}}
        },
        [user_id: "@_ap_alice___mobilizon:kazarma"] ->
          {:ok, "event_id"}
      end)

      %{
        local_id: "reply_to_id",
        remote_id: "http://mobilizon/@group/c/comment",
        room_id: "!room:kazarma"
      }
      |> Bridge.create_event()

      assert :ok = handle_activity(note_with_reply_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "reply_to_id",
                 remote_id: "http://mobilizon/@group/c/comment",
                 room_id: "!room:kazarma"
               },
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "transaction handler for event in collection" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def event_fixture do
      %MatrixAppService.Event{
        event_id: "event_id",
        sender: "@bob:kazarma",
        room_id: "!room:kazarma",
        type: "m.room.message",
        content: %{
          "msgtype" => "m.text",
          "body" => "hello",
          "formatted_body" => "hello"
        }
      }
    end

    def event_with_reply_fixture do
      %MatrixAppService.Event{
        event_id: "event_id",
        sender: "@bob:kazarma",
        room_id: "!room:kazarma",
        type: "m.room.message",
        content: %{
          "msgtype" => "m.text",
          "body" => "hello",
          "formatted_body" => "hello",
          "m.relates_to" => %{
            "m.in_reply_to" => %{
              "event_id" => "reply_to_id"
            }
          }
        }
      }
    end

    setup do
      {:ok, group} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "MN:Collection",
            "name" => "Group",
            "preferredUsername" => "group",
            "url" => "http://mobilizon/@group",
            "id" => "http://mobilizon/@group",
            "username" => "group@mobilizon",
            "members" => "http://mobilizon/@group/members"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://mobilizon/@group"
        })

      group
      |> ActivityPub.Actor.format_remote_actor()
      |> ActivityPub.Actor.set_cache()

      ActivityPub.Object.do_insert(%{data: %{"id" => "http://mobilizon/comments/note_id"}})

      %{
        data: %{"type" => "collection"},
        local_id: "!room:kazarma",
        remote_id: "http://mobilizon/@group"
      }
      |> Bridge.create_room()

      :ok
    end

    test "when receiving an event that's not a reply it creates a new group discussion" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/-/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/-/bob/followers",
              "following" => "http://kazarma/-/bob/following",
              "icon" => nil,
              "id" => "http://kazarma/-/bob",
              "inbox" => "http://kazarma/-/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/-/bob/outbox",
              "preferredUsername" => "bob",
              "type" => "Person"
            },
            deactivated: false,
            id: nil,
            keys: _,
            local: true,
            pointer_id: nil,
            username: "bob@kazarma"
          },
          context: _,
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://mobilizon/@group",
            "content" => "hello",
            "context" => _,
            "conversation" => _,
            "tag" => [],
            "to" => ["http://mobilizon/@group/members"],
            "type" => "Note",
            "inReplyTo" => "http://mobilizon/comments/note_id"
          },
          to: ["http://mobilizon/@group/members"]
        } ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      %{
        local_id: "reply_to_id",
        remote_id: "http://mobilizon/comments/note_id",
        room_id: "!room:kazarma"
      }
      |> Bridge.create_event()

      assert :ok == Kazarma.Matrix.Transaction.new_event(event_with_reply_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "reply_to_id",
                 remote_id: "http://mobilizon/comments/note_id",
                 room_id: "!room:kazarma"
               },
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving an event replying to a discussion it forwards the message to the corresponding discussion" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/-/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/-/bob/followers",
              "following" => "http://kazarma/-/bob/following",
              "icon" => nil,
              "id" => "http://kazarma/-/bob",
              "inbox" => "http://kazarma/-/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/-/bob/outbox",
              "preferredUsername" => "bob",
              "type" => "Person"
            },
            deactivated: false,
            id: nil,
            keys: _,
            local: true,
            pointer_id: nil,
            username: "bob@kazarma"
          },
          context: _,
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://mobilizon/@group",
            "content" => "hello",
            "context" => _,
            "conversation" => _,
            "tag" => [],
            "to" => ["http://mobilizon/@group/members"],
            "type" => "Note"
          },
          to: ["http://mobilizon/@group/members"]
        } ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      %{
        local_id: "reply_to_id",
        remote_id: "http://mobilizon/comments/note_id",
        room_id: "!room:kazarma"
      }
      |> Bridge.create_event()

      assert :ok == Kazarma.Matrix.Transaction.new_event(event_with_reply_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "reply_to_id",
                 remote_id: "http://mobilizon/comments/note_id",
                 room_id: "!room:kazarma"
               },
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end
end
