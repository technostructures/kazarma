# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomTypes.DirectMessageTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "activity handler (handle_activity/1) for private Note" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      alice = create_ap_user_alice()
      create_local_matrix_user_bob()
      create_local_matrix_user_carole()

      {:ok, actor: alice}
    end

    # @TODO: test errors that can happen

    def note_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "to" => ["http://kazarma/-/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "context" => "conversation1",
            "source" => "hello",
            "id" => "note_id",
            "actor" => "http://pleroma.com/pub/actors/alice",
            "attributedTo" => "http://pleroma.com/pub/actors/alice",
            "to" => ["http://kazarma/-/bob"],
            "attachment" => nil
          }
        }
      }
    end

    def note_fixture_adding_another_user do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "to" => ["http://kazarma/-/bob", "http://kazarma/-/carole"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "context" => "conversation1",
            "source" => "hello",
            "id" => "note_id",
            "actor" => "http://pleroma.com/pub/actors/alice",
            "attributedTo" => "http://pleroma.com/pub/actors/alice",
            "to" => ["http://kazarma/-/bob", "http://kazarma/-/carole"],
            "attachment" => nil
          }
        }
      }
    end

    def note_with_attachments_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "to" => ["http://kazarma/-/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "context" => "conversation1",
            "actor" => "http://pleroma.com/pub/actors/alice",
            "attributedTo" => "http://pleroma.com/pub/actors/alice",
            "content" => "hello",
            "id" => "note_id",
            "attachment" => [
              %{
                "mediaType" => "image/svg+xml",
                "name" => nil,
                "type" => "Document",
                "url" =>
                  "https://technostructures.org/app/themes/technostructures/resources/logo.svg"
              },
              %{
                "mediaType" => "image/png",
                "name" => nil,
                "type" => "Document",
                "url" =>
                  "https://technostructures.org/app/themes/technostructures/resources/favicon.png"
              }
            ],
            "source" => "hello",
            "summary" => "something",
            "to" => ["http://kazarma/-/bob"]
          }
        }
      }
    end

    test "when receiving a Note activity for an existing conversation gets the corresponding room and forwards the message" do
      Kazarma.Matrix.TestClient
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        {"hello \uFEFF", "hello"},
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "conversation1",
        data: %{
          "type" => "direct_message",
          "to" => ["@alice.pleroma.com:kazarma", "@bob:kazarma"]
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(note_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a Note activity for an existing conversation with another mention for a Matrix it invites them" do
      Kazarma.Matrix.TestClient
      |> expect_send_state_event(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        "m.room.member",
        "@carole:kazarma",
        %{"membership" => "invite"},
        "!invite_event"
      )
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        {"hello \uFEFF", "hello"},
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "conversation1",
        data: %{
          "type" => "direct_message",
          "to" => ["@alice.pleroma.com:kazarma", "@bob:kazarma"]
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(note_fixture_adding_another_user())

      assert [
               %MatrixAppService.Bridge.Room{
                 local_id: "!room:kazarma",
                 remote_id: "conversation1",
                 data: %{
                   "type" => "direct_message",
                   "to" => ["@alice.pleroma.com:kazarma", "@bob:kazarma", "@carole:kazarma"]
                 }
               }
             ] = Bridge.list_rooms()

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a Note activity for a first conversation creates a new room and sends forward the message" do
      Kazarma.Matrix.TestClient
      |> expect_create_room(
        "@alice.pleroma.com:kazarma",
        [
          visibility: :private,
          name: nil,
          topic: nil,
          is_direct: false,
          invite: ["@bob:kazarma"],
          room_version: "5"
        ],
        "!room:kazarma"
      )
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        {"hello \uFEFF", "hello"},
        "event_id"
      )

      assert :ok = handle_activity(note_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 local_id: "!room:kazarma",
                 remote_id: "conversation1",
                 data: %{
                   "type" => "direct_message",
                   "to" => ["@alice.pleroma.com:kazarma", "@bob:kazarma"]
                 }
               }
             ] = Bridge.list_rooms()

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a Note activity with attachments and some text forwards the attachments and the text" do
      Kazarma.Matrix.TestClient
      |> expect_upload_something(
        "@alice.pleroma.com:kazarma",
        "mxc://serveur/example"
      )
      |> expect_upload_something(
        "@alice.pleroma.com:kazarma",
        "mxc://serveur/example2"
      )
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        %{
          "body" => "hello\nmxc://serveur/example\nmxc://serveur/example2 \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "hello<br><img src=\"mxc://serveur/example\" title=\"Attachment\"><br><img src=\"mxc://serveur/example2\" title=\"Attachment\">",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "conversation1",
        data: %{
          "type" => "direct_message",
          "to" => ["@alice.pleroma.com:kazarma", "@bob:kazarma"]
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(note_with_attachments_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a Note activity with attachments and no text forwards only the attachments" do
      Kazarma.Matrix.TestClient
      |> expect_upload_something(
        "@alice.pleroma.com:kazarma",
        "mxc://serveur/example"
      )
      |> expect_upload_something(
        "@alice.pleroma.com:kazarma",
        "mxc://serveur/example2"
      )
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        %{
          "body" => "mxc://serveur/example\nmxc://serveur/example2 \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "<img src=\"mxc://serveur/example\" title=\"Attachment\"><br><img src=\"mxc://serveur/example2\" title=\"Attachment\">",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "conversation1",
        data: %{
          "type" => "direct_message",
          "to" => ["@alice.pleroma.com:kazarma", "@bob:kazarma"]
        }
      }
      |> Bridge.create_room()

      note =
        note_with_attachments_fixture()
        |> update_in([Access.key!(:object), Access.key!(:data), "content"], fn _ -> nil end)
        |> update_in([Access.key!(:object), Access.key!(:data), "source"], fn _ -> nil end)

      assert :ok = handle_activity(note)

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "activity handler (handle_activity/1) for private Note with reply" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "http://pleroma.com/pub/objects/reply_to",
          room_id: "!room:kazarma"
        })

      alice = create_ap_user_alice()
      create_local_matrix_user_bob()

      {:ok, actor: alice}
    end

    def note_with_reply_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "to" => ["http://kazarma/-/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "context" => "conversation1",
            "source" => "hello",
            "id" => "note_id",
            "actor" => "http://pleroma.com/pub/actors/alice",
            "attributedTo" => "http://pleroma.com/pub/actors/alice",
            "inReplyTo" => "http://pleroma.com/pub/objects/reply_to",
            "to" => ["http://kazarma/-/bob"],
            "attachment" => nil
          }
        }
      }
    end

    test "when receiving a Note activity with a reply for an existing conversation gets the corresponding room and forwards the message with a reply" do
      Kazarma.Matrix.TestClient
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        %{
          "msgtype" => "m.text",
          "body" => "hello \uFEFF",
          "m.relates_to" => %{
            "m.in_reply_to" => %{
              "event_id" => "local_id"
            }
          }
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "conversation1",
        data: %{
          "type" => "direct_message",
          "to" => ["@alice.pleroma.com:kazarma", "@bob:kazarma"]
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(note_with_reply_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "http://pleroma.com/pub/objects/reply_to",
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
end
