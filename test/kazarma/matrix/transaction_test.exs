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
  alias Kazarma.Bridge
  alias MatrixAppService.Event

  # Those are accounts created on public ActivityPub instances
  @pleroma_user_server "pleroma.interhacker.space"
  @pleroma_user_name "test_user_bob2"
  @pleroma_user_displayname "Bob"
  @pleroma_puppet_username "_ap_#{@pleroma_user_name}___#{@pleroma_user_server}"
  @pleroma_puppet_address "@#{@pleroma_puppet_username}:kazarma"

  @mastodon_user_server "mastodon.social"
  @mastodon_user_name "test_user_alice1"
  @mastodon_user_displayname "Alice"
  @mastodon_puppet_username "_ap_#{@mastodon_user_name}___#{@mastodon_user_server}"
  @mastodon_puppet_address "@#{@mastodon_puppet_username}:kazarma"

  describe "User invitation" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def invitation_event_direct_fixture do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite", "is_direct" => true},
        sender: "@alice:kazarma",
        room_id: "!direct_room:kazarma",
        state_key: @pleroma_puppet_address
      }
    end

    def invitation_event_direct_nonexisting do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite", "is_direct" => true},
        room_id: "!direct_room:kazarma",
        state_key: "@_ap_nonexisting1___pleroma:kazarma"
      }
    end

    def invitation_event_multiuser_fixture_pleroma do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: "!room:kazarma",
        state_key: @pleroma_puppet_address
      }
    end

    def invitation_event_multiuser_fixture_mastodon do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: "!room:kazarma",
        state_key: @mastodon_puppet_address
      }
    end

    def invitation_event_multiuser_fixture_nonexisting do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite"},
        room_id: "!room:kazarma",
        state_key: "@_ap_nonexisting2___pleroma:kazarma"
      }
    end

    test "when a puppet user is invited to a direct room a Bridge record is created and the room is joined" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!direct_room:kazarma", user_id: @pleroma_puppet_address ->
        :ok
      end)
      |> expect(:register, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}
      end)
      |> expect(:put_displayname, fn
        @pleroma_puppet_address, @pleroma_user_displayname, user_id: @pleroma_puppet_address ->
          :ok
      end)
      |> expect(:create_room, 1, fn
        [
          visibility: :public,
          name: "Bob",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: @pleroma_puppet_username,
          initial_state: [%{content: %{guest_access: :can_join}, type: "m.room.guest_access"}]
        ],
        [user_id: @pleroma_puppet_address] ->
          {:ok, %{"room_id" => "!room_id:kazarma"}}
      end)
      |> expect(:get_data, fn
        @pleroma_puppet_address, "m.direct", user_id: @pleroma_puppet_address ->
          {:ok, %{}}
      end)
      |> expect(:put_data, fn
        @pleroma_puppet_address,
        "m.direct",
        %{"@alice:kazarma" => ["!direct_room:kazarma"]},
        user_id: @pleroma_puppet_address ->
          :ok
      end)

      assert :ok == new_event(invitation_event_direct_fixture())

      assert %{
               local_id: "!direct_room:kazarma",
               data: %{
                 "to_ap_id" => "https://#{@pleroma_user_server}/users/#{@pleroma_user_name}",
                 "type" => "chat"
               }
             } = Bridge.get_room_by_local_id("!direct_room:kazarma")
    end

    test "when a puppet user is invited to a multiuser room a Bridge record is created and the room is joined" do
      Kazarma.Matrix.TestClient
      |> expect(:register, 2, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}

        [
          username: @mastodon_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => @mastodon_puppet_address}}
      end)
      |> expect(:create_room, 2, fn
        [
          visibility: :public,
          name: "Bob",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: @pleroma_puppet_username,
          initial_state: [%{content: %{guest_access: :can_join}, type: "m.room.guest_access"}]
        ],
        [user_id: @pleroma_puppet_address] ->
          {:ok, %{"room_id" => "!room_id:kazarma"}}

        [
          visibility: :public,
          name: "Alice",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: @mastodon_puppet_username,
          initial_state: [%{content: %{guest_access: :can_join}, type: "m.room.guest_access"}]
        ],
        [user_id: @mastodon_puppet_address] ->
          {:ok, %{"room_id" => "!room_id:kazarma"}}
      end)
      |> expect(:put_displayname, 2, fn
        @pleroma_puppet_address, @pleroma_user_displayname, user_id: @pleroma_puppet_address ->
          :ok

        @mastodon_puppet_address, @mastodon_user_displayname, user_id: @mastodon_puppet_address ->
          :ok
      end)
      |> expect(:join, 2, fn
        "!room:kazarma", user_id: @pleroma_puppet_address ->
          :ok

        "!room:kazarma", user_id: @mastodon_puppet_address ->
          :ok
      end)

      assert :ok == new_event(invitation_event_multiuser_fixture_pleroma())

      assert %{data: %{"to" => [@pleroma_puppet_address], "type" => "direct_message"}} =
               Bridge.get_room_by_local_id("!room:kazarma")

      assert :ok == new_event(invitation_event_multiuser_fixture_mastodon())

      assert %{
               data: %{
                 "to" => [
                   @mastodon_puppet_address,
                   @pleroma_puppet_address
                 ],
                 "type" => "direct_message"
               }
             } = Bridge.get_room_by_local_id("!room:kazarma")
    end

    test "when a nonexisting puppet user is invited nothing happens" do
      assert :ok == new_event(invitation_event_direct_nonexisting())
      assert nil == Bridge.get_room_by_local_id("!direct_room:kazarma")
      assert :ok == new_event(invitation_event_multiuser_fixture_nonexisting())
      assert nil == Bridge.get_room_by_local_id("!room:kazarma")
    end
  end

  describe "Profile update" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def profile_update_fixture(displayname, avatar_url) do
      %Event{
        event_id: "event_id",
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
        Bridge.create_user(%{
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
      |> expect(:client, fn ->
        %{base_url: "http://matrix"}
      end)
      |> expect(:get_profile, fn
        "@alice:kazarma" ->
          {:ok, %{"displayname" => "old_name", "avatar_url" => "mxc://server/old_avatar"}}
      end)

      assert :ok == new_event(profile_update_fixture("new_name", "mxc://server/new_avatar"))
    end

    test "it updates the avatar if it has changed" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 2, fn ->
        %{base_url: "http://matrix"}
      end)
      |> expect(:get_profile, fn
        "@alice:kazarma" ->
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
      |> expect(:client, fn ->
        %{base_url: "http://matrix"}
      end)
      |> expect(:get_profile, fn
        "@alice:kazarma" ->
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
      event_id: "event_id",
      sender: "@bob:kazarma",
      room_id: "!room:kazarma",
      type: "m.room.message",
      content: %{"msgtype" => "m.text", "body" => "hello"}
    }
  end

  def message_with_attachment_fixture do
    %Event{
      event_id: "event_id",
      sender: "@bob:kazarma",
      room_id: "!room:kazarma",
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
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: nil,
          data: %{"to_ap_id" => "alice@pleroma", "type" => "chat"}
        })

      :ok
    end

    test "when receiving a message it forwards it as ChatMessage activity" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/actors/bob/followers",
              "followings" => "http://kazarma/actors/bob/following",
              "id" => "http://kazarma/actors/bob",
              "inbox" => "http://kazarma/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/actors/bob/outbox",
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
            "actor" => "http://kazarma/actors/bob",
            "attributedTo" => "http://kazarma/actors/bob",
            "content" => "hello",
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        },
        nil ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      assert :ok == new_event(message_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a message with an attachment it forwards it in a ChatMessage activity" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> %{base_url: "http://example.org"} end)
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/actors/bob/followers",
              "followings" => "http://kazarma/actors/bob/following",
              "icon" => nil,
              "id" => "http://kazarma/actors/bob",
              "inbox" => "http://kazarma/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/actors/bob/outbox",
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
            "actor" => "http://kazarma/actors/bob",
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
            "attributedTo" => "http://kazarma/actors/bob",
            "content" => "",
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        },
        nil ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      assert :ok == new_event(message_with_attachment_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "Message reception in multiuser room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: "http://pleroma/contexts/context",
          data: %{
            "to" => [@pleroma_puppet_address],
            "type" => "direct_message"
          }
        })

      :ok
    end

    test "when receiving a message it forwards it as Note activity" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:register, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}
      end)
      |> expect(:create_room, 1, fn
        [
          visibility: :public,
          name: "Bob",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: @pleroma_puppet_username,
          initial_state: [%{content: %{guest_access: :can_join}, type: "m.room.guest_access"}]
        ],
        [user_id: @pleroma_puppet_address] ->
          {:ok, %{"room_id" => "!room_id:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        @pleroma_puppet_address, @pleroma_user_displayname, user_id: @pleroma_puppet_address ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/actors/bob/followers",
              "followings" => "http://kazarma/actors/bob/following",
              "id" => "http://kazarma/actors/bob",
              "inbox" => "http://kazarma/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/actors/bob/outbox",
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
            "actor" => "http://kazarma/actors/bob",
            "attributedTo" => "http://kazarma/actors/bob",
            "content" => "hello",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note"
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        },
        nil ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      assert :ok == new_event(message_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when receiving a message with an attachment it forwards it in a Note activity" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> %{base_url: "http://example.org"} end)
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:register, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}
      end)
      |> expect(:create_room, 1, fn
        [
          visibility: :public,
          name: "Bob",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: @pleroma_puppet_username,
          initial_state: [%{content: %{guest_access: :can_join}, type: "m.room.guest_access"}]
        ],
        [user_id: @pleroma_puppet_address] ->
          {:ok, %{"room_id" => "!room_id:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        @pleroma_puppet_address, @pleroma_user_displayname, user_id: @pleroma_puppet_address ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/actors/bob/followers",
              "followings" => "http://kazarma/actors/bob/following",
              "icon" => nil,
              "id" => "http://kazarma/actors/bob",
              "inbox" => "http://kazarma/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/actors/bob/outbox",
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
            "actor" => "http://kazarma/actors/bob",
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
            "attributedTo" => "http://kazarma/actors/bob",
            "content" => "",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note"
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        },
        nil ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      assert :ok == new_event(message_with_attachment_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "Message reception with reply in multiuser room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: "http://pleroma/contexts/context",
          data: %{
            "to" => [@pleroma_puppet_address],
            "type" => "direct_message"
          }
        })

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "reply_to_id",
          remote_id: "http://pleroma/objects/reply_to",
          room_id: "!room:kazarma"
        })

      :ok
    end

    def message_with_reply_fixture do
      %Event{
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

    test "when receiving a message with reply it forwards it as Note activity with reply" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:register, fn
        [
          username: @pleroma_puppet_username,
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => @pleroma_puppet_address}}
      end)
      |> expect(:create_room, 1, fn
        [
          visibility: :public,
          name: "Bob",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: @pleroma_puppet_username,
          initial_state: [%{content: %{guest_access: :can_join}, type: "m.room.guest_access"}]
        ],
        [user_id: @pleroma_puppet_address] ->
          {:ok, %{"room_id" => "!room_id:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        @pleroma_puppet_address, @pleroma_user_displayname, user_id: @pleroma_puppet_address ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/actors/bob/followers",
              "followings" => "http://kazarma/actors/bob/following",
              "id" => "http://kazarma/actors/bob",
              "inbox" => "http://kazarma/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/actors/bob/outbox",
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
            "actor" => "http://kazarma/actors/bob",
            "attributedTo" => "http://kazarma/actors/bob",
            "content" => "hello",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note",
            "inReplyTo" => "http://pleroma/objects/reply_to"
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        },
        nil ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      assert :ok == new_event(message_with_reply_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "reply_to_id",
                 remote_id: "http://pleroma/objects/reply_to",
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

  describe "Message deletion" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      ActivityPub.Object.insert(%{data: %{"id" => "remote_id"}})

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "remote_id",
          room_id: "!room:kazarma"
        })

      :ok
    end

    def redaction_fixture do
      %Event{
        sender: "@bob:kazarma",
        room_id: "!room:kazarma",
        event_id: "delete_event_id",
        type: "m.room.redaction",
        redacts: "local_id",
        content: %{"reason" => "Just want to"}
      }
    end

    test "when receiving a redaction event it forwards it as Delete activity" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:delete, fn
        %ActivityPub.Object{
          data: %{"id" => "remote_id"},
          id: _,
          local: true,
          pointer_id: nil,
          public: nil
        },
        true,
        %ActivityPub.Actor{
          ap_id: "http://kazarma/actors/bob",
          data: %{
            :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
            "capabilities" => %{"acceptsChatMessages" => true},
            "followers" => "http://kazarma/actors/bob/followers",
            "followings" => "http://kazarma/actors/bob/following",
            "icon" => nil,
            "id" => "http://kazarma/actors/bob",
            "inbox" => "http://kazarma/actors/bob/inbox",
            "manuallyApprovesFollowers" => false,
            "name" => "Bob",
            "outbox" => "http://kazarma/actors/bob/outbox",
            "preferredUsername" => "bob",
            "type" => "Person"
          },
          deactivated: false,
          id: nil,
          keys: _,
          local: true,
          pointer_id: nil,
          username: "bob@kazarma"
        } ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "delete_object_id"}}}}
      end)

      assert :ok = new_event(redaction_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "remote_id",
                 room_id: "!room:kazarma"
               },
               %MatrixAppService.Bridge.Event{
                 local_id: "delete_event_id",
                 remote_id: "delete_object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  def formatted_message_fixture do
    %Event{
      event_id: "event_id",
      sender: "@bob:kazarma",
      room_id: "!room:kazarma",
      type: "m.room.message",
      content: %{
        "msgtype" => "m.text",
        "format" => "org.matrix.custom.html",
        "body" => """
        > This is a reply
        of 2 lines
        Hello @alice:kazarma
        """,
        "formatted_body" => """
        <mx-reply>> This is a reply
        of 2 lines</mx-reply>Hello <a href="https://matrix.to/#/@alice:kazarma">Alice</a>!
        """
      }
    }
  end

  describe "Text body conversion" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: nil,
          data: %{"to_ap_id" => "alice@pleroma", "type" => "chat"}
        })

      :ok
    end

    test "it removes mx-reply tags and convert mentions" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, 2, fn
        "@bob:kazarma" ->
          {:ok, %{"displayname" => "Bob"}}

        "@alice:kazarma" ->
          {:ok, %{"displayname" => "Alice"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/actors/bob/followers",
              "followings" => "http://kazarma/actors/bob/following",
              "id" => "http://kazarma/actors/bob",
              "inbox" => "http://kazarma/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/actors/bob/outbox",
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
            "actor" => "http://kazarma/actors/bob",
            "attributedTo" => "http://kazarma/actors/bob",
            "content" => """
            Hello <span class="h-card"><a href="http://kazarma/actors/alice" class="u-url mention">@<span>alice@kazarma</span></a></span>!
            """,
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        },
        nil ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      assert :ok == new_event(formatted_message_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "Text body conversion when mentioned user is not found" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: nil,
          data: %{"to_ap_id" => "alice@pleroma", "type" => "chat"}
        })

      :ok
    end

    test "it removes mx-reply tags and convert mentions" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, 2, fn
        "@bob:kazarma" ->
          {:ok, %{"displayname" => "Bob"}}

        "@alice:kazarma" ->
          {:error, :not_found}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/actors/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/actors/bob/followers",
              "followings" => "http://kazarma/actors/bob/following",
              "id" => "http://kazarma/actors/bob",
              "inbox" => "http://kazarma/actors/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Bob",
              "outbox" => "http://kazarma/actors/bob/outbox",
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
            "actor" => "http://kazarma/actors/bob",
            "attributedTo" => "http://kazarma/actors/bob",
            "content" => """
            Hello <span class="h-card">@<span>alice@kazarma</span></span>!
            """,
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        },
        nil ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "object_id"}}}}
      end)

      assert :ok == new_event(formatted_message_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end
end
