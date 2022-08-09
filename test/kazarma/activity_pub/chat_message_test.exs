# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Kazarma.ActivityPub.ChatMessageTest do
  use Kazarma.DataCase

  import Mox
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
          "to" => ["http://kazarma/pub/actors/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "ChatMessage",
            "content" => "hello"
          }
        }
      }
    end

    def chat_message_with_attachment_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma/pub/actors/alice",
          "to" => ["http://kazarma/pub/actors/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "ChatMessage",
            "content" => "hello",
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
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 4, fn
        [user_id: "@_ap_alice___pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
        #         :client_alice, "@_ap_alice___pleroma:kazarma" ->
        #         {:ok, %{"displayname" => "Alice"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "@_ap_alice___pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:get_data, 2, fn
        :client_alice, "@_ap_alice___pleroma:kazarma", "m.direct" ->
          {:ok, %{}}
      end)
      |> expect(:put_data, fn
        :client_alice,
        "@_ap_alice___pleroma:kazarma",
        "m.direct",
        %{"@bob:kazarma" => ["!room:kazarma"]} ->
          :ok
      end)
      |> expect(:create_room, fn
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
                                  {"hello \uFEFF", "hello"},
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, :something}
      end)

      assert :ok = handle_activity(chat_message_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 local_id: "!room:kazarma",
                 data: %{
                   "type" => "chat_message",
                   "to_ap_id" => "http://pleroma/pub/actors/alice"
                 }
               }
             ] = Kazarma.Matrix.Bridge.list_rooms()
    end

    test "when receiving a ChatMessage activity for an existing conversation gets the corresponding room and forwards the message" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 2, fn
        [user_id: "@_ap_alice___pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "@_ap_alice___pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:get_data, fn :client_alice, "@_ap_alice___pleroma:kazarma", "m.direct" ->
        {:ok, %{"@bob:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello"},
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, :something}
      end)

      assert :ok = handle_activity(chat_message_fixture())
    end

    test "when receiving a ChatMessage activity with an attachement and some text forwards both the attachment and the text" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 2, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "_ap_alice___pleroma:kazarma"] -> :client_alice
        [user_id: "@_ap_alice___pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:get_data, fn :client_alice, "@_ap_alice___pleroma:kazarma", "m.direct" ->
        {:ok, %{"@bob:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:create_attachment_message, fn :client_alice,
                                               {:data, _, "example.jpg"},
                                               [
                                                 body: "example.jpg",
                                                 filename: "example.jpg",
                                                 mimetype: "image/jpeg",
                                                 msgtype: "m.image"
                                               ] ->
        {:ok,
         %{msgtype: "m.image", info: %{"filename" => "example.jpeg", "mimetype" => "image/jpeg"}}}
      end)
      |> expect(:send_message, 2, fn
        "!room:kazarma", {"hello \uFEFF", "hello"}, [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}

        "!room:kazarma",
        %{
          msgtype: "m.image",
          info: %{
            "filename" => "example.jpeg",
            "mimetype" => "image/jpeg"
          }
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}
      end)

      assert :ok = handle_activity(chat_message_with_attachment_fixture())
    end

    test "when receiving a ChatMessage activity with an attachement and no text forwards only the attachment" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 2, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "_ap_alice___pleroma:kazarma"] -> :client_alice
        [user_id: "@_ap_alice___pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:get_data, fn :client_alice, "@_ap_alice___pleroma:kazarma", "m.direct" ->
        {:ok, %{"@bob:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:create_attachment_message, fn :client_alice,
                                               {:data, _, "example.jpg"},
                                               [
                                                 body: "example.jpg",
                                                 filename: "example.jpg",
                                                 mimetype: "image/jpeg",
                                                 msgtype: "m.image"
                                               ] ->
        {:ok,
         %{msgtype: "m.image", info: %{"filename" => "example.jpeg", "mimetype" => "image/jpeg"}}}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{
          msgtype: "m.image",
          info: %{
            "filename" => "example.jpeg",
            "mimetype" => "image/jpeg"
          }
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}
      end)

      chat_message =
        update_in(
          chat_message_with_attachment_fixture(),
          [Access.key!(:object), Access.key!(:data), "content"],
          fn _ -> nil end
        )

      assert :ok = handle_activity(chat_message)
    end
  end
end
