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

    test "when receiving a ChatMessage activity for a first conversation creates a new room and sends forward the message" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 4, fn
        [user_id: "@ap_alice=pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "ap_alice=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" => "@ap_alice=pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
        #         :client_alice, "@ap_alice=pleroma:kazarma" ->
        #         {:ok, %{"displayname" => "Alice"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "@ap_alice=pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:get_data, 2, fn
        :client_alice, "@ap_alice=pleroma:kazarma", "m.direct" ->
          {:ok, %{}}
      end)
      |> expect(:put_data, fn
        :client_alice,
        "@ap_alice=pleroma:kazarma",
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
        [user_id: "@ap_alice=pleroma:kazarma"] ->
          {:ok, %{"room_id" => "!room:kazarma"}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello \uFEFF"},
                                  [user_id: "@ap_alice=pleroma:kazarma"] ->
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
        [user_id: "@ap_alice=pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "ap_alice=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" => "@ap_alice=pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "@ap_alice=pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:get_data, fn :client_alice, "@ap_alice=pleroma:kazarma", "m.direct" ->
        {:ok, %{"@bob:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello \uFEFF"},
                                  [user_id: "@ap_alice=pleroma:kazarma"] ->
        {:ok, :something}
      end)

      assert :ok = handle_activity(chat_message_fixture())
    end
  end
end
