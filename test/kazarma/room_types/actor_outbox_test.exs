# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomTypes.ActorOutboxTest do
  @moduledoc """
  Transaction tests for events received from the Matrix server.
  We use existing Pleroma and Matrix accounts so we can create corresponding
  puppets.
  """
  use Kazarma.DataCase

  import Kazarma.ActivityPub.Adapter
  import Kazarma.Matrix.Transaction
  alias Kazarma.Bridge
  alias MatrixAppService.Event

  # Those are accounts created on public ActivityPub instances
  @pleroma_user_server "pleroma.interhacker.space"
  @pleroma_user_name "test_user_bob2"
  @pleroma_user_displayname "Bob"
  @pleroma_user_ap_id "https://pleroma.interhacker.space/users/test_user_bob2"
  @pleroma_puppet_username "_ap_#{@pleroma_user_name}___#{@pleroma_user_server}"
  @pleroma_puppet_address "@#{@pleroma_puppet_username}:kazarma"

  describe "When sending a message to a timeline room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!foo:kazarma",
          remote_id: @pleroma_user_ap_id,
          data: %{"matrix_id" => @pleroma_puppet_address, "type" => "ap_user"}
        })

      :ok
    end

    def message_fixture do
      %Event{
        sender: "@bob:kazarma",
        room_id: "!foo:kazarma",
        type: "m.room.message",
        content: %{"msgtype" => "m.text", "body" => "hello"}
      }
    end

    test "it sends a public Note mentioning the AP user" do
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
      |> expect(:put_displayname, fn
        @pleroma_puppet_address, @pleroma_user_displayname, user_id: @pleroma_puppet_address ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/-/bob",
            data: %{
              :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/-/bob/followers",
              "followings" => "http://kazarma/-/bob/following",
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
          context: _,
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" =>
              "<span class=\"h-card\"><a href=\"https://pleroma.interhacker.space/users/test_user_bob2\" class=\"u-url mention\">@<span>test_user_bob2@pleroma.interhacker.space</span></a></span>hello",
            "context" => _,
            "conversation" => _,
            "tag" => [
              %{
                "href" => "https://pleroma.interhacker.space/users/test_user_bob2",
                "name" => "@test_user_bob2@pleroma.interhacker.space",
                "type" => "Mention"
              }
            ],
            "to" => [
              "https://www.w3.org/ns/activitystreams#Public",
              "https://pleroma.interhacker.space/users/test_user_bob2"
            ],
            "type" => "Note"
          },
          to: [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://pleroma.interhacker.space/users/test_user_bob2"
          ]
        },
        nil ->
          {:ok, :activity}
      end)

      assert :ok == new_event(message_fixture())
    end
  end

  describe "activity handler (handle_activity/1) for public Note" do
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

    def public_note_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://kazarma/-/bob",
            "https://www.w3.org/ns/activitystreams#Public"
          ]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "source" => "hello",
            "id" => "note_id",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil
          }
        }
      }
    end

    def public_note_fixture_with_content do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://kazarma/-/bob",
            "https://www.w3.org/ns/activitystreams#Public"
          ]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "content" => "hello",
            "id" => "note_id",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil
          }
        }
      }
    end

    test "receiving a public note forwards it to the puppet's timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello"},
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, "event_id"}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_alice___pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_note_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "receiving a public note forwards it to the puppet's timeline room even without a source part" do
      Kazarma.Matrix.TestClient
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello"},
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, "event_id"}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_alice___pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_note_fixture_with_content())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "activity handler (handle_activity/1) for public Note with reply" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, alice} =
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

      {:ok, bob} =
        ActivityPub.Object.insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://pleroma/pub/actors/bob",
            "id" => "http://pleroma/pub/actors/bob",
            "username" => "bob@pleroma"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://pleroma/pub/actors/bob"
        })

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "note_id",
          room_id: "!room:kazarma"
        })

      {:ok, alice: alice, bob: bob}
    end

    def public_note_with_reply_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://kazarma/-/bob",
            "https://www.w3.org/ns/activitystreams#Public"
          ]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "source" => "hello",
            "id" => "reply_note_id",
            "actor" => "http://pleroma/pub/actors/bob",
            "inReplyTo" => "note_id",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil
          }
        }
      }
    end

    test "when receiving a Note activity with a reply for an existing conversation gets the corresponding room and forwards the message with a reply" do
      Kazarma.Matrix.TestClient
      |> expect(:register, fn
        [
          username: "_ap_bob___pleroma",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => "_ap_bob___pleroma:kazarma"}}

        [
          username: "_ap_alice___pleroma",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_bob___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "msgtype" => "m.text",
                                    "body" => "hello \uFEFF",
                                    "formatted_body" => "hello",
                                    "m.relates_to" => %{
                                      "m.in_reply_to" => %{
                                        "event_id" => "local_id"
                                      }
                                    }
                                  },
                                  [user_id: "@_ap_bob___pleroma:kazarma"] ->
        {:ok, "reply_id"}
      end)

      %{
        local_id: "local_id",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_alice___pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/bob",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_bob___pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_note_with_reply_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               },
               %MatrixAppService.Bridge.Event{
                 local_id: "reply_id",
                 remote_id: "reply_note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "When an actor follows the relay actor" do
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

    def follow_fixture do
      %{
        data: %{
          "type" => "Follow",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => "http://kazarma/-/relay"
        }
      }
    end

    def unfollow_fixture do
      %{
        data: %{
          "type" => "Undo",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => %{
            "type" => "Follow",
            "object" => "http://kazarma/-/relay"
          }
        }
      }
    end

    test "following the relay actor makes it accept, follow back and creates the actor room" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@relay:kazarma" ->
        {:ok, %{"displayname" => "Relay"}}
      end)
      |> expect(:register, fn
        [
          username: "_ap_alice___pleroma",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        "@_ap_alice___pleroma:kazarma", "Alice", user_id: "@_ap_alice___pleroma:kazarma" ->
          :ok
      end)
      |> expect(:create_room, fn
        [
          visibility: :public,
          name: "Alice",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: "_ap_alice___pleroma",
          initial_state: [
            %{content: %{guest_access: :can_join}, type: "m.room.guest_access"},
            %{content: %{history_visibility: :world_readable}, type: "m.room.history_visibility"}
          ]
        ],
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, %{"room_id" => "!room:kazarma"}}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{"body" => "has started bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Relay",
              "preferredUsername" => "relay",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma",
            deactivated: false
          },
          object: %{
            "actor" => "http://pleroma/pub/actors/alice",
            "object" => "http://kazarma/-/relay",
            "type" => "Follow"
          },
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)
      |> expect(:follow, fn
        %ActivityPub.Actor{
          id: nil,
          data: %{
            "id" => "http://kazarma/-/relay",
            "name" => "Relay",
            "preferredUsername" => "relay",
            "type" => "Person"
          },
          local: true,
          ap_id: "http://kazarma/-/relay",
          username: "relay@kazarma"
        },
        %ActivityPub.Actor{
          data: %{
            "id" => "http://pleroma/pub/actors/alice",
            "name" => "Alice",
            "preferredUsername" => "alice",
            "type" => "Person",
            "url" => "http://pleroma/pub/actors/alice",
            "username" => "alice@pleroma"
          },
          local: false,
          ap_id: "http://pleroma/pub/actors/alice",
          username: "alice@pleroma"
        } ->
          :ok
      end)

      assert :ok = handle_activity(follow_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{"matrix_id" => "@_ap_alice___pleroma:kazarma", "type" => "ap_user"},
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end

    test "following the relay actor makes it accept, follow back and gets the actor room by alias if it already exists" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@relay:kazarma" ->
        {:ok, %{"displayname" => "Relay"}}
      end)
      |> expect(:register, fn
        [
          username: "_ap_alice___pleroma",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        "@_ap_alice___pleroma:kazarma", "Alice", user_id: "@_ap_alice___pleroma:kazarma" ->
          :ok
      end)
      |> expect(:create_room, fn
        [
          visibility: :public,
          name: "Alice",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: "_ap_alice___pleroma",
          initial_state: [
            %{content: %{guest_access: :can_join}, type: "m.room.guest_access"},
            %{content: %{history_visibility: :world_readable}, type: "m.room.history_visibility"}
          ]
        ],
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:error, 400, %{"errcode" => "M_ROOM_IN_USE"}}
      end)
      |> expect(:get_alias, fn
        "#_ap_alice___pleroma:kazarma" ->
          {:ok, {"!room:kazarma", nil}}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{"body" => "has started bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Relay",
              "preferredUsername" => "relay",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma",
            deactivated: false
          },
          object: %{
            "actor" => "http://pleroma/pub/actors/alice",
            "object" => "http://kazarma/-/relay",
            "type" => "Follow"
          },
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)
      |> expect(:follow, fn
        %ActivityPub.Actor{
          id: nil,
          data: %{
            "id" => "http://kazarma/-/relay",
            "name" => "Relay",
            "preferredUsername" => "relay",
            "type" => "Person"
          },
          local: true,
          ap_id: "http://kazarma/-/relay",
          username: "relay@kazarma"
        },
        %ActivityPub.Actor{
          data: %{
            "id" => "http://pleroma/pub/actors/alice",
            "name" => "Alice",
            "preferredUsername" => "alice",
            "type" => "Person",
            "url" => "http://pleroma/pub/actors/alice",
            "username" => "alice@pleroma"
          },
          local: false,
          ap_id: "http://pleroma/pub/actors/alice",
          username: "alice@pleroma"
        } ->
          :ok
      end)

      assert :ok = handle_activity(follow_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{"matrix_id" => "@_ap_alice___pleroma:kazarma", "type" => "ap_user"},
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end

    test "following the relay actor makes it accept, follow back and starts bridging again is relay had previously been unfollowed" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@relay:kazarma" ->
        {:ok, %{"displayname" => "Relay"}}
      end)
      |> expect(:register, fn
        [
          username: "_ap_alice___pleroma",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        "@_ap_alice___pleroma:kazarma", "Alice", user_id: "@_ap_alice___pleroma:kazarma" ->
          :ok
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{"body" => "has started bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Relay",
              "preferredUsername" => "relay",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma",
            deactivated: false
          },
          object: %{
            "actor" => "http://pleroma/pub/actors/alice",
            "object" => "http://kazarma/-/relay",
            "type" => "Follow"
          },
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)
      |> expect(:follow, fn
        %ActivityPub.Actor{
          id: nil,
          data: %{
            "id" => "http://kazarma/-/relay",
            "name" => "Relay",
            "preferredUsername" => "relay",
            "type" => "Person"
          },
          local: true,
          ap_id: "http://kazarma/-/relay",
          username: "relay@kazarma"
        },
        %ActivityPub.Actor{
          data: %{
            "id" => "http://pleroma/pub/actors/alice",
            "name" => "Alice",
            "preferredUsername" => "alice",
            "type" => "Person",
            "url" => "http://pleroma/pub/actors/alice",
            "username" => "alice@pleroma"
          },
          local: false,
          ap_id: "http://pleroma/pub/actors/alice",
          username: "alice@pleroma"
        } ->
          :ok
      end)

      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: "http://pleroma/pub/actors/alice",
          data: %{"type" => "deactivated_ap_user", "matrix_id" => "@_ap_alice___pleroma:kazarma"}
        })

      assert :ok = handle_activity(follow_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{"matrix_id" => "@_ap_alice___pleroma:kazarma", "type" => "ap_user"},
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end
  end

  describe "When an actor unfollows the relay actor" do
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

      {:ok, relay} =
        ActivityPub.Object.insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Relay",
            "preferredUsername" => "relay",
            "url" => "http://kazarma/-/relay",
            "id" => "http://kazarma/-/relay",
            "username" => "relay@kazarma"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://kazarma/-/relay"
        })

      {:ok, actor: actor, relay: relay}
    end

    def follow_fixture do
      %{
        data: %{
          "type" => "Follow",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => "http://kazarma/-/relay"
        }
      }
    end

    def unfollow_fixture do
      %{
        data: %{
          "type" => "Undo",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => %{
            "type" => "Follow",
            "object" => "http://kazarma/-/relay"
          }
        }
      }
    end

    test "unfollowing the relay actor makes it unfollow back and deactivates the actor room" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@relay:kazarma" ->
        {:ok, %{"displayname" => "Relay"}}
      end)
      |> expect(:register, fn
        [
          username: "_ap_alice___pleroma",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => "@_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:put_displayname, fn
        "@_ap_alice___pleroma:kazarma", "Alice", user_id: "@_ap_alice___pleroma:kazarma" ->
          :ok
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{"body" => "has stopped bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:unfollow, fn
        %ActivityPub.Actor{
          id: nil,
          data: %{
            "id" => "http://kazarma/-/relay",
            "name" => "Relay",
            "preferredUsername" => "relay",
            "type" => "Person"
          },
          local: true,
          ap_id: "http://kazarma/-/relay",
          username: "relay@kazarma"
        },
        %ActivityPub.Actor{
          data: %{
            "id" => "http://pleroma/pub/actors/alice",
            "name" => "Alice",
            "preferredUsername" => "alice",
            "type" => "Person",
            "url" => "http://pleroma/pub/actors/alice",
            "username" => "alice@pleroma"
          },
          local: false,
          ap_id: "http://pleroma/pub/actors/alice",
          username: "alice@pleroma"
        } ->
          :ok
      end)

      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: "http://pleroma/pub/actors/alice",
          data: %{"type" => "ap_user", "matrix_id" => "@_ap_alice___pleroma:kazarma"}
        })

      assert :ok = handle_activity(unfollow_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{
                   "matrix_id" => "@_ap_alice___pleroma:kazarma",
                   "type" => "deactivated_ap_user"
                 },
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end
  end
end
