defmodule Kazarma.ActivityPub.AdapterTest do
  use Kazarma.DataCase

  import Mox
  import Kazarma.ActivityPub.Adapter

  describe "ActivityPub request for a local user (get_actor_by_username/1)" do
    setup :verify_on_exit!

    test "when asked for an existing matrix users returns the corresponding actor" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> nil end)
      |> expect(:get_profile, fn _, "@alice:kazarma" ->
        {:ok, %{"displayname" => "Alice"}}
      end)

      assert {:ok, actor} = get_actor_by_username("alice")

      assert %ActivityPub.Actor{
               local: true,
               deactivated: false,
               username: "alice@kazarma",
               ap_id: "http://kazarma/pub/actors/alice",
               data: %{
                 "preferredUsername" => "alice",
                 "id" => "http://kazarma/pub/actors/alice",
                 "type" => "Person",
                 "name" => "Alice",
                 "followers" => "http://kazarma/pub/actors/alice/followers",
                 "followings" => "http://kazarma/pub/actors/alice/following",
                 "inbox" => "http://kazarma/pub/actors/alice/inbox",
                 "outbox" => "http://kazarma/pub/actors/alice/outbox",
                 "manuallyApprovesFollowers" => false,
                 endpoints: %{
                   "sharedInbox" => "http://kazarma/pub/shared_inbox"
                 }
               }
             } = actor
    end

    test "when asked for a nonexisting matrix users returns an error tuple" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> nil end)
      |> expect(:get_profile, fn _, "@nonexisting:kazarma" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = get_actor_by_username("nonexisting")
    end
  end

  describe "activity handler (handle_activity/1)" do
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
      |> expect(:client, 2, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "ap_alice=pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "ap_alice=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" => "ap_alice=pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "ap_alice=pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:get_data, fn :client_bob, "@bob:kazarma", "m.direct" ->
        {:ok, %{}}
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
                 data: %{"type" => "chat_message", "to_ap" => "http://pleroma/pub/actors/alice"}
               }
             ] = Kazarma.Matrix.Bridge.list_rooms()
    end

    test "when receiving a ChatMessage activity for an existing conversation gets the corresponding room and forwards the message" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 2, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "ap_alice=pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "ap_alice=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" => "ap_alice=pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "ap_alice=pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:get_data, fn :client_bob, "@bob:kazarma", "m.direct" ->
        {:ok, %{"@ap_alice=pleroma:kazarma" => ["!room:kazarma"]}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello \uFEFF"},
                                  [user_id: "@ap_alice=pleroma:kazarma"] ->
        {:ok, :something}
      end)

      assert :ok = handle_activity(chat_message_fixture())
    end

    # @TODO: test errors that can happen

    def note_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => ["http://kazarma/pub/actors/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "source" => "hello",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context"
          }
        }
      }
    end

    test "when receiving a Note activity for a first conversation creates a new room and sends forward the message" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 1, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "ap_alice=pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "ap_alice=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" => "ap_alice=pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "ap_alice=pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:create_room, fn
        [
          visibility: :private,
          name: nil,
          topic: nil,
          is_direct: false,
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

      assert :ok = handle_activity(note_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/contexts/context",
                 data: %{
                   "type" => "note",
                   "to" => ["@ap_alice=pleroma:kazarma", "@bob:kazarma"]
                 }
               }
             ] = Kazarma.Matrix.Bridge.list_rooms()
    end

    test "when receiving a Note activity for an existing conversation gets the corresponding room and forwards the message" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 1, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "ap_alice=pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "ap_alice=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" => "ap_alice=pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:put_displayname, fn :client_alice, "ap_alice=pleroma:kazarma", "Alice" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello \uFEFF"},
                                  [user_id: "@ap_alice=pleroma:kazarma"] ->
        {:ok, :something}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/contexts/context",
        data: %{
          "type" => "note",
          "to" => ["@ap_alice=pleroma:kazarma", "@bob:kazarma"]
        }
      }
      |> Kazarma.Matrix.Bridge.create_room()

      assert :ok = handle_activity(note_fixture())
    end
  end

  describe "Maybe register Matrix puppet user (maybe_create_remote_actor/1)" do
    setup :verify_on_exit!

    test "it registers a puppet user" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn
        [user_id: "@ap_bob=pleroma:kazarma"] -> :client_bob
      end)
      |> expect(:register, fn [
                                username: "ap_bob=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" =>  "@ap_bob=pleroma:kazarma"}}
      end)
      |> expect(:put_displayname, fn :client_bob, "@ap_bob=pleroma:kazarma", "Bob" ->
        :ok
      end)

      assert :ok = maybe_create_remote_actor(%ActivityPub.Actor{username: "bob@pleroma", data: %{"name" => "Bob"}})
    end
  end
end
