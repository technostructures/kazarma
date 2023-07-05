# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomTypes.ChatTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter

  describe "activity handler (handle_activity/1) for ChatMessage" do
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
              "mediaType" => "image/jpeg",
              "name" => nil,
              "type" => "Document",
              "url" => [
                %{
                  "href" => "http://example.com/example.jpg",
                  "mediaType" => "image/jpeg",
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
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn "@_ap_alice___pleroma:kazarma",
                                     "Alice",
                                     user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:get_data, 2, fn
        "@_ap_alice___pleroma:kazarma", "m.direct", user_id: "@_ap_alice___pleroma:kazarma" ->
          {:ok, %{}}
      end)
      |> expect(:put_data, fn
        "@_ap_alice___pleroma:kazarma",
        "m.direct",
        %{"@bob:kazarma" => ["!room:kazarma"]},
        user_id: "@_ap_alice___pleroma:kazarma" ->
          :ok
      end)
      |> expect(:create_room, 1, fn
        [
          visibility: :private,
          name: nil,
          topic: nil,
          is_direct: true,
          invite: ["@bob:kazarma"],
          room_version: "5"
        ],
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, %{"room_id" => "!room:kazarma"}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "body" => "hello \uFEFF",
                                    "format" => "org.matrix.custom.html",
                                    "formatted_body" => "hello",
                                    "msgtype" => "m.text"
                                  },
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, "event_id"}
      end)

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
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn "@_ap_alice___pleroma:kazarma",
                                     "Alice",
                                     user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:get_data, fn "@_ap_alice___pleroma:kazarma",
                              "m.direct",
                              user_id: "@_ap_alice___pleroma:kazarma" ->
        {:ok, %{"@bob:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "body" => "hello \uFEFF",
                                    "format" => "org.matrix.custom.html",
                                    "formatted_body" => "hello",
                                    "msgtype" => "m.text"
                                  },
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, "event_id"}
      end)

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
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:get_data, fn "@_ap_alice___pleroma:kazarma",
                              "m.direct",
                              user_id: "@_ap_alice___pleroma:kazarma" ->
        {:ok, %{"@bob:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:upload, fn
        _examplejpg_data,
        [filename: "example.jpg", mimetype: "image/jpeg"],
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "mxc://serveur/example"}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{
          "body" => "hello\nmxc://serveur/example \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "hello<br><img src=\"mxc://serveur/example\" title=\"Attachment\">",
          "msgtype" => "m.text"
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "event_id1"}
      end)

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
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:get_data, fn "@_ap_alice___pleroma:kazarma",
                              "m.direct",
                              user_id: "@_ap_alice___pleroma:kazarma" ->
        {:ok, %{"@bob:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:upload, fn
        _examplejpg_data,
        [filename: "example.jpg", mimetype: "image/jpeg"],
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "mxc://serveur/example"}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{
          "body" => "mxc://serveur/example \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "<img src=\"mxc://serveur/example\" title=\"Attachment\">",
          "msgtype" => "m.text"
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "event_id"}
      end)

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
