# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.TransactionTest do
  @moduledoc """
  Transaction tests for events received from the Matrix server.
  We use existing Pleroma and Matrix accounts so we can create corresponding
  puppets.
  """
  use Kazarma.DataCase

  import Mox
  import Kazarma.Matrix.Transaction
  alias MatrixAppService.Event

  # Those are accounts created on public ActivityPub instances
  @pleroma_user_server "kiwifarms.cc"
  @pleroma_user_name "test_user_bob2"
  @pleroma_user_displayname "Bob"
  @pleroma_puppet_username "ap_#{@pleroma_user_name}=#{@pleroma_user_server}"
  @pleroma_puppet_address "@#{@pleroma_puppet_username}:kazarma"

  @mastodon_user_server "mastodon.social"
  @mastodon_user_name "test_user_alice1"
  @mastodon_user_displayname "Alice"
  @mastodon_puppet_username "ap_#{@mastodon_user_name}=#{@mastodon_user_server}"
  @mastodon_puppet_address "@#{@mastodon_puppet_username}:kazarma"

  describe "User invitation" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def invitation_event_direct_fixture do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "invite", "is_direct" => true},
        sender: "@alice:kazarma",
        room_id: "!direct_room:kazarma",
        state_key: @pleroma_puppet_address
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
        state_key: @pleroma_puppet_address
      }
    end

    def invitation_event_multiuser_fixture_mastodon do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: "!room:kazarma",
        state_key: @mastodon_puppet_address
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
      |> expect(:client, 4, fn [user_id: @pleroma_puppet_address] ->
        :client_puppet
      end)
      |> expect(:join, fn :client_puppet, "!direct_room:kazarma" ->
        :ok
      end)
      |> expect(:register, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}
      end)
      |> expect(:put_displayname, fn
        :client_puppet, @pleroma_puppet_address, @pleroma_user_displayname ->
          :ok
      end)
      |> expect(:get_data, fn
        :client_puppet, @pleroma_puppet_address, "m.direct" ->
          {:ok, %{}}
      end)
      |> expect(:put_data, fn
        :client_puppet,
        @pleroma_puppet_address,
        "m.direct",
        %{"@alice:kazarma" => ["!direct_room:kazarma"]} ->
          :ok
      end)

      assert :ok == new_event(invitation_event_direct_fixture())

      assert %{
               local_id: "!direct_room:kazarma",
               data: %{
                 "to_ap_id" => "https://#{@pleroma_user_server}/users/#{@pleroma_user_name}",
                 "type" => "chat_message"
               }
             } = Kazarma.Matrix.Bridge.get_room_by_local_id("!direct_room:kazarma")
    end

    test "when a puppet user is invited to a multiuser room a Bridge record is created and the room is joined" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 4, fn
        [user_id: @pleroma_puppet_address] -> :client_pleroma
        [user_id: @mastodon_puppet_address] -> :client_mastodon
      end)
      |> expect(:register, 2, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}

        [
          username: @mastodon_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => @mastodon_puppet_address}}
      end)
      |> expect(:put_displayname, 2, fn
        :client_pleroma, @pleroma_puppet_address, @pleroma_user_displayname ->
          :ok

        :client_mastodon, @mastodon_puppet_address, @mastodon_user_displayname ->
          :ok
      end)
      |> expect(:join, 2, fn
        :client_pleroma, "!room:kazarma" ->
          :ok

        :client_mastodon, "!room:kazarma" ->
          :ok
      end)

      assert :ok == new_event(invitation_event_multiuser_fixture_pleroma())

      assert %{data: %{"to" => [@pleroma_puppet_address], "type" => "note"}} =
               Kazarma.Matrix.Bridge.get_room_by_local_id("!room:kazarma")

      assert :ok == new_event(invitation_event_multiuser_fixture_mastodon())

      assert %{
               data: %{
                 "to" => [
                   @mastodon_puppet_address,
                   @pleroma_puppet_address
                 ],
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

  describe "Profile update" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def profile_update_fixture(displayname, avatar_url) do
      %Event{
        type: "m.room.member",
        content: %{"displayname" => displayname, "avatar_url" => avatar_url},
        room_id: "!room:kazarma",
        # try with @alice:matrix
        state_key: "@alice:kazarma"
      }
    end

    setup do
      {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()

      {:ok, _user} =
        Kazarma.Matrix.Bridge.create_user(%{
          local_id: "@alice:kazarma",
          remote_id: "http://kazarma/users/alice",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/users/alice",
              "preferredUsername" => "alice",
              "name" => "old_name",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/old_avatar"}
            },
            keys: keys
          }
        })

      :ok
    end

    test "it does nothing if nothing has changed" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        %{base_url: "http://matrix"}
      end)

      assert :ok == new_event(profile_update_fixture("old_name", "mxc://server/old_avatar"))
    end

    test "it does nothing if not confirmed by profile" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 2, fn ->
        %{base_url: "http://matrix"}
      end)
      |> expect(:get_profile, fn
        _, "@alice:kazarma" ->
          {:ok, %{"displayname" => "old_name", "avatar_url" => "mxc://server/old_avatar"}}
      end)

      assert :ok == new_event(profile_update_fixture("new_name", "mxc://server/new_avatar"))
    end

    test "it updates the avatar if it has changed" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 3, fn ->
        %{base_url: "http://matrix"}
      end)
      |> expect(:get_profile, fn
        _, "@alice:kazarma" ->
          {:ok, %{"displayname" => "old_name", "avatar_url" => "mxc://server/new_avatar"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:update, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/users/alice",
            data: %{
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/new_avatar"},
              "id" => "http://kazarma/users/alice",
              "name" => "old_name",
              "preferredUsername" => "alice"
            },
            local: true,
            username: "alice@kazarma"
          },
          cc: [],
          object: %{
            "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/new_avatar"},
            "id" => "http://kazarma/users/alice",
            "name" => "old_name",
            "preferredUsername" => "alice",
            "url" => "http://kazarma/users/alice"
          },
          to: [nil, "https://www.w3.org/ns/activitystreams#Public"]
        } ->
          :ok
      end)

      assert :ok == new_event(profile_update_fixture("old_name", "mxc://server/new_avatar"))
    end

    test "it updates the displayname if it has changed" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 2, fn ->
        %{base_url: "http://matrix"}
      end)
      |> expect(:get_profile, fn
        _, "@alice:kazarma" ->
          Kazarma.ActivityPub.TestServer
          |> expect(:update, fn
            %{
              actor: %ActivityPub.Actor{
                ap_id: "http://kazarma/users/alice",
                data: %{
                  "icon" => %{
                    "url" => "http://matrix/_matrix/media/r0/download/server/old_avatar"
                  },
                  "id" => "http://kazarma/users/alice",
                  "name" => "new_name",
                  "preferredUsername" => "alice"
                },
                local: true,
                username: "alice@kazarma"
              },
              cc: [],
              object: %{
                "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/old_avatar"},
                "id" => "http://kazarma/users/alice",
                "name" => "new_name",
                "preferredUsername" => "alice",
                "url" => "http://kazarma/users/alice"
              },
              to: [nil, "https://www.w3.org/ns/activitystreams#Public"]
            } ->
              :ok
          end)

          {:ok, %{"displayname" => "new_name", "avatar_url" => "mxc://server/old_avatar"}}
      end)

      assert :ok == new_event(profile_update_fixture("new_name", "mxc://server/old_avatar"))
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

  def message_with_attachment_fixture do
    %Event{
      sender: "@bob:kazarma",
      room_id: "!foo:kazarma",
      type: "m.room.message",
      content: %{
        "body" => "hello.jpg",
        "info" => %{
          "h" => 200,
          "mimetype" => "image/jpeg",
          "size" => 30_000,
          "w" => 200
        },
        "msgtype" => "m.image",
        "url" => "mxc://kazarma/aabbccddeeffgg"
      }
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
        {:ok, %{"displayname" => "Bob"}}
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
            keys: _,
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

    test "when receiving a message with an attachment it forwards it in a ChatMessage activity" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> :client_kazarma end)
      |> expect(:client, fn -> %{base_url: "http://example.org"} end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
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
              "icon" => nil,
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
            keys: _,
            local: true,
            pointer_id: nil,
            username: "bob@kazarma"
          },
          context: nil,
          object: %{
            "actor" => "http://kazarma/pub/actors/bob",
            "attachment" => %{
              "mediaType" => "image/jpeg",
              "name" => nil,
              "type" => "Document",
              "url" => [
                %{
                  "href" => "http://example.org/_matrix/media/r0/download/kazarma/aabbccddeeffgg",
                  "mediaType" => "image/jpeg",
                  "type" => "Link"
                }
              ]
            },
            "attributedTo" => "http://kazarma/pub/actors/bob",
            "content" => "hello.jpg",
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        },
        nil ->
          {:ok, :activity}
      end)

      assert :ok == new_event(message_with_attachment_fixture())
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
            "to" => [@pleroma_puppet_address],
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
        [user_id: @pleroma_puppet_address] ->
          :client_bob
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:register, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}
      end)
      |> expect(:put_displayname, fn
        :client_bob, @pleroma_puppet_address, @pleroma_user_displayname ->
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
            keys: _,
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
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note"
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        },
        nil ->
          {:ok, :activity}
      end)

      assert :ok == new_event(message_fixture())
    end

    test "when receiving a message with an attachment it forwards it in a Note activity" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> :client_kazarma end)
      |> expect(:client, fn -> %{base_url: "http://example.org"} end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:client, fn
        [user_id: @pleroma_puppet_address] ->
          :client_bob
      end)
      |> expect(:register, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}
      end)
      |> expect(:put_displayname, fn
        :client_bob, @pleroma_puppet_address, @pleroma_user_displayname ->
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
              "icon" => nil,
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
            keys: _,
            local: true,
            pointer_id: nil,
            username: "bob@kazarma"
          },
          context: "http://pleroma/contexts/context",
          object: %{
            "actor" => "http://kazarma/pub/actors/bob",
            "attachment" => %{
              "mediaType" => "image/jpeg",
              "name" => nil,
              "type" => "Document",
              "url" => [
                %{
                  "href" => "http://example.org/_matrix/media/r0/download/kazarma/aabbccddeeffgg",
                  "mediaType" => "image/jpeg",
                  "type" => "Link"
                }
              ]
            },
            "attributedTo" => "http://kazarma/pub/actors/bob",
            "content" => "hello.jpg",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note"
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        },
        nil ->
          {:ok, :activity}
      end)

      assert :ok == new_event(message_with_attachment_fixture())
    end
  end
end
