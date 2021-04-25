defmodule Kazarma.Matrix.TransactionTest do
  @moduledoc """
  Transaction tests for events received from the Matrix server.
  We use existing Pleroma and Matrix accounts so we can create corresponding
  puppets.
  We should create special accounts for that, in the meantime let's hope Karen
  and Eugen dont change their ActivitiyPub names too often.
  """
  use Kazarma.DataCase

  import Mox
  import Kazarma.Matrix.Transaction
  alias MatrixAppService.Event

  describe "User invitation" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def invitation_event_direct_fixture do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "invite", "is_direct" => true},
        room_id: "!direct_room:kazarma",
        state_key: "@ap_karen=kawen.space:kazarma"
      }
    end

    def invitation_event_direct_nonexisting do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "invite", "is_direct" => true},
        room_id: "!direct_room:kazarma",
        state_key: "@ap_nonexisting1=pleroma:kazarma"
      }
    end

    def invitation_event_multiuser_fixture_pleroma do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: "!room:kazarma",
        state_key: "@ap_karen=kawen.space:kazarma"
      }
    end

    def invitation_event_multiuser_fixture_mastodon do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: "!room:kazarma",
        state_key: "@ap_gargron=mastodon.social:kazarma"
      }
    end

    def invitation_event_multiuser_fixture_nonexisting do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: "!room:kazarma",
        state_key: "@ap_nonexisting2=pleroma:kazarma"
      }
    end

    test "when a puppet user is invited to a direct room a Bridge record is created and the room is joined" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 2, fn [user_id: "@ap_karen=kawen.space:kazarma"] -> :client_puppet end)
      |> expect(:join, fn :client_puppet, "!direct_room:kazarma" ->
        :ok
      end)
      |> expect(:register, fn
        [
          username: "ap_karen=kawen.space",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => "@ap_karen=kawen.space:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        :client_puppet, "@ap_karen=kawen.space:kazarma", "叶恋 (妹)" ->
          :ok
      end)

      assert :ok == new_event(invitation_event_direct_fixture())

      assert %{
               local_id: "!direct_room:kazarma",
               data: %{
                 "to_ap_id" => "https://kawen.space/users/karen",
                 "type" => "chat_message"
               }
             } = Kazarma.Matrix.Bridge.get_room_by_local_id("!direct_room:kazarma")
    end

    test "when a puppet user is invited to a multiuser room a Bridge record is created and the room is joined" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 4, fn
        [user_id: "@ap_karen=kawen.space:kazarma"] -> :client_pleroma
        [user_id: "@ap_gargron=mastodon.social:kazarma"] -> :client_mastodon
      end)
      |> expect(:register, 2, fn
        [
          username: "ap_karen=kawen.space",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => "@ap_karen=kawen.space:kazarma"}}

        [
          username: "ap_argron=mastodon.social",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => "@ap_gargron=mastodon.social:kazarma"}}
      end)
      |> expect(:put_displayname, 2, fn
        :client_pleroma, "@ap_karen=kawen.space:kazarma", "叶恋 (妹)" ->
          :ok

        :client_mastodon, "@ap_gargron=mastodon.social:kazarma", "Eugen" ->
          :ok
      end)
      |> expect(:join, 2, fn
        :client_pleroma, "!room:kazarma" ->
          :ok

        :client_mastodon, "!room:kazarma" ->
          :ok
      end)

      assert :ok == new_event(invitation_event_multiuser_fixture_pleroma())

      assert %{data: %{"to" => ["@ap_karen=kawen.space:kazarma"], "type" => "note"}} =
               Kazarma.Matrix.Bridge.get_room_by_local_id("!room:kazarma")

      assert :ok == new_event(invitation_event_multiuser_fixture_mastodon())

      assert %{
               data: %{
                 "to" => ["@ap_gargron=mastodon.social:kazarma", "@ap_karen=kawen.space:kazarma"],
                 "type" => "note"
               }
             } = Kazarma.Matrix.Bridge.get_room_by_local_id("!room:kazarma")
    end

    test "when a nonexisting puppet user is invited nothing happens" do
      assert :ok == new_event(invitation_event_direct_nonexisting())
      assert nil == Kazarma.Matrix.Bridge.get_room_by_local_id("!direct_room:kazarma")
      assert :ok == new_event(invitation_event_multiuser_fixture_nonexisting())
      assert nil == Kazarma.Matrix.Bridge.get_room_by_local_id("!room:kazarma")
    end
  end

  def message_fixture do
    %Event{
      sender: "@bob:kazarma",
      room_id: "!foo:kazarma",
      type: "m.room.message",
      content: %{"msgtype" => "m.text", "body" => "hello"}
    }
  end

  describe "Message reception in direct room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Kazarma.Matrix.Bridge.create_room(%{
          local_id: "!foo:kazarma",
          remote_id: nil,
          data: %{"to_ap_id" => "alice@pleroma", "type" => "chat_message"}
        })

      :ok
    end

    test "when receiving a message it forwards it as ChatMessage activity" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Matrix User"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/pub/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/pub/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/pub/actors/bob/followers",
              "followings" => "http://kazarma/pub/actors/bob/following",
              "id" => "http://kazarma/pub/actors/bob",
              "inbox" => "http://kazarma/pub/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Matrix User",
              "outbox" => "http://kazarma/pub/actors/bob/outbox",
              "preferredUsername" => "bob",
              "type" => "Person"
            },
            deactivated: false,
            id: nil,
            keys: nil,
            local: true,
            pointer_id: nil,
            username: "bob@kazarma"
          },
          context: nil,
          object: %{
            "actor" => "http://kazarma/pub/actors/bob",
            "attributedTo" => "http://kazarma/pub/actors/bob",
            "content" => "hello",
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        },
        nil ->
          {:ok, :activity}
      end)

      assert :ok == new_event(message_fixture())
    end
  end

  describe "Message reception in multiuser room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Kazarma.Matrix.Bridge.create_room(%{
          local_id: "!foo:kazarma",
          remote_id: "http://pleroma/contexts/context",
          data: %{
            "to" => ["@ap_karen=kawen.space:kazarma"],
            "type" => "note"
          }
        })

      :ok
    end

    test "when receiving a message it forwards it as Note activity" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, fn
        [user_id: "ap_karen=kawen.space:kazarma"] ->
          :client_karen
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:register, fn
        [
          username: "ap_karen=kawen.space",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => "ap_karen=kawen.space:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        :client_karen, "ap_karen=kawen.space:kazarma", "叶恋 (妹)" ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/pub/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/pub/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/pub/actors/bob/followers",
              "followings" => "http://kazarma/pub/actors/bob/following",
              "id" => "http://kazarma/pub/actors/bob",
              "inbox" => "http://kazarma/pub/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/pub/actors/bob/outbox",
              "preferredUsername" => "bob",
              "type" => "Person"
            },
            deactivated: false,
            id: nil,
            keys: nil,
            local: true,
            pointer_id: nil,
            username: "bob@kazarma"
          },
          context: "http://pleroma/contexts/context",
          object: %{
            "actor" => "http://kazarma/pub/actors/bob",
            "attributedTo" => "http://kazarma/pub/actors/bob",
            "content" => "hello",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://kawen.space/users/karen"],
            "type" => "Note"
          },
          to: ["https://kawen.space/users/karen"]
        },
        nil ->
          {:ok, :activity}
      end)

      assert :ok == new_event(message_fixture())
    end
  end
end
