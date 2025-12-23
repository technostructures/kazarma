# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.TransactionTest do
  @moduledoc """
  Transaction tests for events received from the Matrix server.
  We use existing Pleroma and Matrix accounts so we can create corresponding
  puppets.
  """
  use Kazarma.DataCase

  import Kazarma.Matrix.Transaction
  import Kazarma.MatrixMocks
  alias Kazarma.Bridge
  alias MatrixAppService.Event

  # Those are accounts created on public ActivityPub instances
  @pleroma_user_server "pleroma.interhacker.space"
  @pleroma_user_name "pierre"
  @pleroma_user_displayname "Pierre"
  # @pleroma_user_full_username "pierre@pleroma.interhacker.space"
  # @pleroma_user_ap_id "https://pleroma.interhacker.space/users/pierre"
  @pleroma_puppet_username "#{@pleroma_user_name}.#{@pleroma_user_server}"
  @pleroma_puppet_address "@#{@pleroma_puppet_username}:kazarma"

  @mastodon_user_server "mastodon.social"
  @mastodon_user_name "test_user_alice1"
  @mastodon_user_displayname "Alice"
  @mastodon_puppet_username "#{@mastodon_user_name}.#{@mastodon_user_server}"
  @mastodon_puppet_address "@#{@mastodon_puppet_username}:kazarma"

  describe "User invitation" do
    @describetag :external

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
        sender: "@alice:kazarma",
        room_id: "!direct_room:kazarma",
        state_key: "@nonexisting1.interhacker.space:kazarma"
      }
    end

    def invitation_event_multiuser_fixture_pleroma do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite"},
        sender: "@alice:kazarma",
        room_id: "!room:kazarma",
        state_key: @pleroma_puppet_address
      }
    end

    def invitation_event_multiuser_fixture_mastodon do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite"},
        sender: "@alice:kazarma",
        room_id: "!room:kazarma",
        state_key: @mastodon_puppet_address
      }
    end

    def invitation_event_multiuser_fixture_nonexisting do
      %Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "invite"},
        sender: "@alice:kazarma",
        room_id: "!room:kazarma",
        state_key: "@nonexisting2.interhacker.space:kazarma"
      }
    end

    test "when a puppet user is invited to a direct room a Bridge record is created and the room is joined" do
      Kazarma.Matrix.TestClient
      |> expect_join(@pleroma_puppet_address, "!direct_room:kazarma")
      |> expect_register(%{
        username: @pleroma_puppet_username,
        matrix_id: @pleroma_puppet_address,
        displayname: @pleroma_user_displayname
      })
      |> expect_get_data(@pleroma_puppet_address, "m.direct", %{})
      |> expect_put_data(@pleroma_puppet_address, "m.direct", %{
        "@alice:kazarma" => ["!direct_room:kazarma"]
      })

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
      |> expect_get_profile("@alice:kazarma", %{"displayname" => "Alice"})
      |> expect_register(%{
        username: @pleroma_puppet_username,
        matrix_id: @pleroma_puppet_address,
        displayname: @pleroma_user_displayname
      })
      |> expect_register(%{
        username: @mastodon_puppet_username,
        matrix_id: @mastodon_puppet_address,
        displayname: @mastodon_user_displayname
      })
      |> expect_join(@pleroma_puppet_address, "!room:kazarma")
      |> expect_join(@mastodon_puppet_address, "!room:kazarma")

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
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, 2, fn
        "@nonexisting1.interhacker.space:kazarma" ->
          {:error, :not_found}

        "@nonexisting2.interhacker.space:kazarma" ->
          {:error, :not_found}
      end)

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
      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

      {:ok, _user} =
        Bridge.create_user(%{
          local_id: "@alice:kazarma",
          remote_id: "http://kazarma/-/alice",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/-/alice",
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
      |> expect_client()

      assert :ok == new_event(profile_update_fixture("old_name", "mxc://server/old_avatar"))
    end

    test "it does nothing if not confirmed by profile" do
      Kazarma.Matrix.TestClient
      |> expect_client()
      |> expect_get_profile("@alice:kazarma", %{
        "displayname" => "old_name",
        "avatar_url" => "mxc://server/old_avatar"
      })

      assert :ok == new_event(profile_update_fixture("new_name", "mxc://server/new_avatar"))
    end

    test "it updates the avatar if it has changed" do
      Kazarma.Matrix.TestClient
      |> expect_client()
      |> expect_client()
      |> expect_get_profile("@alice:kazarma", %{
        "displayname" => "old_name",
        "avatar_url" => "mxc://server/new_avatar"
      })

      Kazarma.ActivityPub.TestServer
      |> expect(:update, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/-/alice",
            data: %{
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/new_avatar"},
              "id" => "http://kazarma/-/alice",
              "name" => "old_name",
              "preferredUsername" => "alice"
            },
            local: true,
            username: "alice@kazarma"
          },
          cc: [],
          object: %{
            "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/new_avatar"},
            "id" => "http://kazarma/-/alice",
            "name" => "old_name",
            "preferredUsername" => "alice",
            "url" => "http://kazarma/-/alice"
          },
          to: [nil, "https://www.w3.org/ns/activitystreams#Public"]
        } ->
          :ok
      end)

      assert :ok == new_event(profile_update_fixture("old_name", "mxc://server/new_avatar"))
    end

    test "it updates the displayname if it has changed" do
      Kazarma.Matrix.TestClient
      |> expect_client()
      |> expect_get_profile("@alice:kazarma", %{
        "displayname" => "new_name",
        "avatar_url" => "mxc://server/old_avatar"
      })

      Kazarma.ActivityPub.TestServer
      |> expect(:update, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/-/alice",
            data: %{
              "icon" => %{
                "url" => "http://matrix/_matrix/media/r0/download/server/old_avatar"
              },
              "id" => "http://kazarma/-/alice",
              "name" => "new_name",
              "preferredUsername" => "alice"
            },
            local: true,
            username: "alice@kazarma"
          },
          cc: [],
          object: %{
            "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/old_avatar"},
            "id" => "http://kazarma/-/alice",
            "name" => "new_name",
            "preferredUsername" => "alice",
            "url" => "http://kazarma/-/alice"
          },
          to: [nil, "https://www.w3.org/ns/activitystreams#Public"]
        } ->
          :ok
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
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})

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
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" => "hello",
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        } ->
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
      |> expect_client()
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})

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
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attachment" => %{
              "mediaType" => "image/jpeg",
              "name" => "",
              "type" => "Document",
              "url" => [
                %{
                  "href" => "http://matrix/_matrix/media/r0/download/kazarma/aabbccddeeffgg",
                  "mediaType" => "image/jpeg",
                  "type" => "Link"
                }
              ]
            },
            "attributedTo" => "http://kazarma/-/bob",
            "content" => "",
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        } ->
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
    @describetag :external

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
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_register(%{
        username: @pleroma_puppet_username,
        matrix_id: @pleroma_puppet_address,
        displayname: @pleroma_user_displayname
      })

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
          context: "http://pleroma/contexts/context",
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" => "hello",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note",
            "tag" => [
              %{
                "href" => "https://#{@pleroma_user_server}/users/#{@pleroma_user_name}",
                "name" => "@#{@pleroma_user_name}",
                "type" => "Mention"
              }
            ]
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        } ->
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
      |> expect_client()
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_register(%{
        username: @pleroma_puppet_username,
        matrix_id: @pleroma_puppet_address,
        displayname: @pleroma_user_displayname
      })

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
          context: "http://pleroma/contexts/context",
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attachment" => %{
              "mediaType" => "image/jpeg",
              "name" => "",
              "type" => "Document",
              "url" => [
                %{
                  "href" => "http://matrix/_matrix/media/r0/download/kazarma/aabbccddeeffgg",
                  "mediaType" => "image/jpeg",
                  "type" => "Link"
                }
              ]
            },
            "attributedTo" => "http://kazarma/-/bob",
            "content" => "",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note"
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        } ->
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
    @describetag :external

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

      ActivityPub.Object.do_insert(%{data: %{"id" => "http://pleroma/objects/reply_to"}})

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
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_register(%{
        username: @pleroma_puppet_username,
        matrix_id: @pleroma_puppet_address,
        displayname: @pleroma_user_displayname
      })

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
          context: "http://pleroma/contexts/context",
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" => "hello",
            "context" => "http://pleroma/contexts/context",
            "conversation" => "http://pleroma/contexts/context",
            "to" => ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"],
            "type" => "Note",
            "inReplyTo" => "http://pleroma/objects/reply_to",
            "tag" => [
              %{
                "href" => "https://#{@pleroma_user_server}/users/#{@pleroma_user_name}",
                "name" => "@#{@pleroma_user_name}",
                "type" => "Mention"
              }
            ]
          },
          to: ["https://#{@pleroma_user_server}/users/#{@pleroma_user_name}"]
        } ->
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

  describe "when receiving a follow command" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      ActivityPub.Object.do_insert(%{data: %{"id" => "remote_id"}})

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "remote_id",
          room_id: "!room:kazarma"
        })

      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!room:kazarma",
          remote_id: "http://kazarma/-/alice"
        })

      {:ok, _user_room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@bob:kazarma", "type" => "ap_user"},
          local_id: "!roombob:kazarma",
          remote_id: "http://kazarma/-/bob"
        })

      :ok
    end

    test "the follow fails if the room is not an ap_user_room" do
      assert {:error, :room_type_should_be_ap_user_room, "!foo:kazarma"} =
               new_event(%Event{
                 type: "m.room.message",
                 room_id: "!foo:kazarma",
                 user_id: "@bob:kazarma",
                 content: %{"body" => "!kazarma follow", "msgtype" => "m.text"}
               })
    end

    test "the follow is executed" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_get_profile("@alice:kazarma", %{"displayname" => "Alice"})

      Kazarma.ActivityPub.TestServer
      |> expect(:follow, fn
        %{
          actor: %ActivityPub.Actor{
            id: nil,
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
            local: true,
            ap_id: "http://kazarma/-/bob",
            username: "bob@kazarma",
            deactivated: false,
            pointer_id: nil
          },
          object: %ActivityPub.Actor{
            id: nil,
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/-/alice/followers",
              "following" => "http://kazarma/-/alice/following",
              "icon" => nil,
              "id" => "http://kazarma/-/alice",
              "inbox" => "http://kazarma/-/alice/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Alice",
              "outbox" => "http://kazarma/-/alice/outbox",
              "preferredUsername" => "alice",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/alice",
            username: "alice@kazarma",
            deactivated: false,
            pointer_id: nil
          }
        } ->
          {:ok}
      end)

      assert {:ok} =
               new_event(%Event{
                 type: "m.room.message",
                 room_id: "!room:kazarma",
                 user_id: "@bob:kazarma",
                 content: %{"body" => "!kazarma follow", "msgtype" => "m.text"}
               })
    end

    test "you can not follow yourself" do
      assert {:error, :sender_and_receiver_should_be_different, "!roombob:kazarma"} =
               new_event(%Event{
                 type: "m.room.message",
                 room_id: "!roombob:kazarma",
                 user_id: "@bob:kazarma",
                 content: %{"body" => "!kazarma follow", "msgtype" => "m.text"}
               })
    end
  end

  describe "when receiving a unfollow" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      ActivityPub.Object.do_insert(%{data: %{"id" => "remote_id"}})

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "remote_id",
          room_id: "!room:kazarma"
        })

      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@alice:kazarma", "type" => "ap_user"},
          local_id: "!room:kazarma",
          remote_id: "http://kazarma/-/alice"
        })

      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@bob:kazarma", "type" => "ap_user"},
          local_id: "!roombob:kazarma",
          remote_id: "http://kazarma/-/bob"
        })

      :ok
    end

    test "the unfollow fails if the room is not an ap_user_room" do
      assert {:error, :room_type_should_be_ap_user_room, "!foo:kazarma"} =
               new_event(%Event{
                 type: "m.room.message",
                 room_id: "!foo:kazarma",
                 user_id: "@bob:kazarma",
                 content: %{"body" => "!kazarma unfollow", "msgtype" => "m.text"}
               })
    end

    test "the unfollow is executed" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_get_profile("@alice:kazarma", %{"displayname" => "Alice"})

      Kazarma.ActivityPub.TestServer
      |> expect(:unfollow, fn
        %{
          actor: %ActivityPub.Actor{
            id: nil,
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
            local: true,
            ap_id: "http://kazarma/-/bob",
            username: "bob@kazarma",
            deactivated: false,
            pointer_id: nil
          },
          object: %ActivityPub.Actor{
            id: nil,
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/-/alice/followers",
              "following" => "http://kazarma/-/alice/following",
              "icon" => nil,
              "id" => "http://kazarma/-/alice",
              "inbox" => "http://kazarma/-/alice/inbox",
              "manuallyApprovesFollowers" => false,
              "name" => "Alice",
              "outbox" => "http://kazarma/-/alice/outbox",
              "preferredUsername" => "alice",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/alice",
            username: "alice@kazarma",
            deactivated: false,
            pointer_id: nil
          }
        } ->
          {:ok}
      end)

      assert {:ok} =
               new_event(%Event{
                 type: "m.room.message",
                 room_id: "!room:kazarma",
                 user_id: "@bob:kazarma",
                 content: %{"body" => "!kazarma unfollow", "msgtype" => "m.text"}
               })
    end

    test "you can not unfollow yourself" do
      assert {:error, :sender_and_receiver_should_be_different, "!roombob:kazarma"} =
               new_event(%Event{
                 type: "m.room.message",
                 room_id: "!roombob:kazarma",
                 user_id: "@bob:kazarma",
                 content: %{"body" => "!kazarma follow", "msgtype" => "m.text"}
               })
    end
  end

  describe "Message deletion" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      ActivityPub.Object.do_insert(%{data: %{"id" => "remote_id"}})

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "remote_id",
          room_id: "!room:kazarma"
        })

      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: nil,
          data: %{"to_ap_id" => "alice@pleroma", "type" => "chat"}
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
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})

      Kazarma.ActivityPub.TestServer
      |> expect(:delete, fn
        %ActivityPub.Object{
          data: %{"id" => "remote_id"},
          id: _,
          local: true,
          pointer_id: nil,
          public: false
        },
        true,
        %ActivityPub.Actor{
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

  describe "Message edition" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      ActivityPub.Object.do_insert(%{data: %{"id" => "remote_id", "content" => "hi1"}})

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "remote_id",
          room_id: "!room:kazarma"
        })

      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: nil,
          data: %{"to_ap_id" => "alice@pleroma", "type" => "chat"}
        })

      :ok
    end

    def replace_fixture do
      %Event{
        sender: "@bob:kazarma",
        room_id: "!room:kazarma",
        event_id: "update_event_id",
        type: "m.room.message",
        content: %{
          "m.new_content" => %{"msgtype" => "m.text", "body" => "hi!"},
          "m.relates_to" => %{"rel_type" => "m.replace", "event_id" => "local_id"}
        }
      }
    end

    test "when receiving a redaction event it forwards it as Update activity" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})

      Kazarma.ActivityPub.TestServer
      |> expect(:update, fn
        %{
          to: _,
          actor: %{
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
          object: %{
            "id" => "remote_id",
            "type" => "Note",
            "content" => "hi!",
            "formerRepresentations" => %{
              "orderedItems" => [%{"content" => "hi1"}],
              "totalItems" => 1,
              "type" => "OrderedCollection"
            }
          }
        } ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "update_object_id"}}}}
      end)

      assert :ok = new_event(replace_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "remote_id",
                 room_id: "!room:kazarma"
               },
               %MatrixAppService.Bridge.Event{
                 local_id: "update_event_id",
                 remote_id: "update_object_id",
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
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_get_profile("@alice:kazarma", %{"displayname" => "Alice"})

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
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" => """
            Hello <span class="h-card"><a href="http://kazarma/-/alice" class="u-url mention">@<span>alice</span></a></span>!
            """,
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage",
            "tag" => [
              %{"href" => "http://kazarma/-/alice", "name" => "@alice", "type" => "Mention"}
            ]
          },
          to: ["alice@pleroma"]
        } ->
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

      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@bob:kazarma",
          remote_id: "http://kazarma/-/bob",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/-/bob",
              "preferredUsername" => "bob",
              "name" => "Bob",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/avatar"},
              "endpoints" => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/-/bob/followers",
              "following" => "http://kazarma/-/bob/following",
              "inbox" => "http://kazarma/-/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "outbox" => "http://kazarma/-/bob/outbox",
              "type" => "Person"
            },
            "keys" => keys
          }
        })

      :ok
    end

    test "it removes mx-reply tags and convert mentions" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, 2, fn
        "@alice:kazarma" ->
          {:error, :not_found}

        "@bob:kazarma" ->
          %{"displayname" => "Bob"}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %{
            ap_id: "http://kazarma/-/bob",
            data: %{
              "endpoints" => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/-/bob/followers",
              "following" => "http://kazarma/-/bob/following",
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
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" => """
            Hello <span class="h-card">@<span>alice@kazarma</span></span>!
            """,
            "to" => ["alice@pleroma"],
            "type" => "ChatMessage"
          },
          to: ["alice@pleroma"]
        } ->
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
