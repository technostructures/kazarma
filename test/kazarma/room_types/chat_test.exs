# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomTypes.ChatTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "activity handler (handle_activity/1) for ChatMessage" do
    setup :set_mox_from_context
    setup :verify_on_exit!

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

    def chat_message_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma/pub/actors/alice",
          "to" => ["http://kazarma/-/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "ChatMessage",
            "content" => "hello",
            "id" => "chat_message_id"
          }
        }
      }
    end

    def chat_message_with_attachment_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma/pub/actors/alice",
          "to" => ["http://kazarma/-/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "ChatMessage",
            "content" => "hello",
            "id" => "chat_message_id",
            "attachment" => %{
              "mediaType" => "image/svg+xml",
              "name" => nil,
              "type" => "Document",
              "url" => [
                %{
                  "href" =>
                    "https://technostructures.org/app/themes/technostructures/resources/logo.svg",
                  "mediaType" => "image/svg+xml",
                  "type" => "Link"
                }
              ]
            }
          }
        }
      }
    end

    test "when receiving a ChatMessage activity for a first conversation creates a new room and sends forward the message" do
      Kazarma.Matrix.TestClient
      |> expect_get_data("@_ap_alice___pleroma:kazarma", "m.direct", %{})
      |> expect_get_data("@_ap_alice___pleroma:kazarma", "m.direct", %{})
      |> expect_put_data("@_ap_alice___pleroma:kazarma", "m.direct", %{
        "@bob:kazarma" => ["!room:kazarma"]
      })
      |> expect_create_room(
        "@_ap_alice___pleroma:kazarma",
        [
          visibility: :private,
          name: nil,
          topic: nil,
          is_direct: true,
          invite: ["@bob:kazarma"],
          room_version: "5"
        ],
        "!room:kazarma"
      )
      |> expect_send_message(
        "@_ap_alice___pleroma:kazarma",
        "!room:kazarma",
        %{
          "body" => "hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "hello",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      assert :ok = handle_activity(chat_message_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 local_id: "!room:kazarma",
                 data: %{
                   "type" => "chat",
                   "to_ap_id" => "http://pleroma/pub/actors/alice"
                 }
               }
             ] = Bridge.list_rooms()

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "chat_message_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a ChatMessage activity for an existing conversation gets the corresponding room and forwards the message" do
      Kazarma.Matrix.TestClient
      |> expect_get_data("@_ap_alice___pleroma:kazarma", "m.direct", %{
        "@bob:kazarma" => ["!room:kazarma"]
      })
      |> expect_send_message(
        "@_ap_alice___pleroma:kazarma",
        "!room:kazarma",
        %{
          "body" => "hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "hello",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      assert :ok = handle_activity(chat_message_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "chat_message_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a ChatMessage activity with an attachement and some text forwards both the attachment and the text" do
      Kazarma.Matrix.TestClient
      |> expect_get_data("@_ap_alice___pleroma:kazarma", "m.direct", %{
        "@bob:kazarma" => ["!room:kazarma"]
      })
      |> expect_upload_something(
        "@_ap_alice___pleroma:kazarma",
        "mxc://serveur/example"
      )
      |> expect_send_message(
        "@_ap_alice___pleroma:kazarma",
        "!room:kazarma",
        %{
          "body" => "hello\nmxc://serveur/example \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "hello<br><img src=\"mxc://serveur/example\" title=\"Attachment\">",
          "msgtype" => "m.text"
        },
        "event_id1"
      )

      assert :ok = handle_activity(chat_message_with_attachment_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id1",
                 remote_id: "chat_message_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a ChatMessage activity with an attachement and no text forwards only the attachment" do
      Kazarma.Matrix.TestClient
      |> expect_get_data("@_ap_alice___pleroma:kazarma", "m.direct", %{
        "@bob:kazarma" => ["!room:kazarma"]
      })
      |> expect_upload_something(
        "@_ap_alice___pleroma:kazarma",
        "mxc://serveur/example"
      )
      |> expect_send_message(
        "@_ap_alice___pleroma:kazarma",
        "!room:kazarma",
        %{
          "body" => "mxc://serveur/example \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "<img src=\"mxc://serveur/example\" title=\"Attachment\">",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      chat_message =
        update_in(
          chat_message_with_attachment_fixture(),
          [Access.key!(:object), Access.key!(:data), "content"],
          fn _ -> nil end
        )

      assert :ok = handle_activity(chat_message)

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "chat_message_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end
end
