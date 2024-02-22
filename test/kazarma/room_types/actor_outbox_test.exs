# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
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
  @pleroma_user_name "pierre"
  @pleroma_user_displayname "Pierre"
  @pleroma_user_full_username "pierre@pleroma.interhacker.space"
  @pleroma_user_ap_id "https://pleroma.interhacker.space/users/pierre"
  @pleroma_puppet_username "_ap_#{@pleroma_user_name}___#{@pleroma_user_server}"
  @pleroma_puppet_address "@#{@pleroma_puppet_username}:kazarma"

  describe "When sending a message to a timeline room" do
    @describetag :external

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
          context: _,
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" => "hello",
            "context" => _,
            "conversation" => _,
            "tag" => [
              %{
                "href" => "#{@pleroma_user_ap_id}",
                "name" => "@#{@pleroma_user_full_username}",
                "type" => "Mention"
              }
            ],
            "to" => [
              "https://www.w3.org/ns/activitystreams#Public",
              "#{@pleroma_user_ap_id}"
            ],
            "type" => "Note"
          },
          to: [
            "https://www.w3.org/ns/activitystreams#Public",
            "#{@pleroma_user_ap_id}"
          ]
        } ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => :object_id}}}}
      end)

      assert :ok == new_event(message_fixture())
    end
  end

  describe "activity handler (handle_activity/1) for public Note" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
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

    def public_note_fixture_with_mention do
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
            "content" =>
              "<p><span class=\"h-card\"><a href=\"http://kazarma/-/bob\" class=\"u-url mention\">@<span>bob</span></a></span> hello</p>",
            "id" => "note_id",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil,
            "tag" => [
              %{
                "href" => "http://kazarma/-/bob",
                "name" => "@bob@kazarma",
                "type" => "Mention"
              }
            ]
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
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
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

    test "receiving a public note with a mention of Matrix user invites them to the timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:send_state_event, fn
        "!room:kazarma",
        "m.room.member",
        "@bob:kazarma",
        %{"membership" => "invite"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "!invite_event"}
      end)
      |> expect(
        :send_message,
        # @TODO
        # should be
        # "body" => "Bob hello \uFEFF",
        # "formatted_body" => "<a href=\"http://matrix.to/#/@bob:kazarma\">Bob</a> hello",
        fn "!room:kazarma",
           %{
             "body" => "@bob hello \uFEFF",
             "format" => "org.matrix.custom.html",
             "formatted_body" =>
               "<p><span><a href=\"http://kazarma/-/bob\">@<span>bob</span></a></span> hello</p>",
             "msgtype" => "m.text"
           },
           [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "event_id"}
        end
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_alice___pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_note_fixture_with_mention())

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

      {:ok, bob} =
        ActivityPub.Object.do_insert(%{
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
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_bob___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "msgtype" => "m.text",
                                    "body" => "hello \uFEFF",
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

    test "when receiving a Note activity with a reply for an existing conversation do nothing if the replying actor is not bridged" do
      %{
        local_id: "local_id",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_alice___pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_note_with_reply_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "activity handler (handle_activity/1) for public Video" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
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

      {:ok, channel} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Channel",
            "name" => "Channel",
            "preferredUsername" => "channel",
            "url" => "http://pleroma/pub/actors/channel",
            "id" => "http://pleroma/pub/actors/channel",
            "username" => "channel@pleroma"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://pleroma/pub/actors/channel"
        })

      {:ok, actor: actor, channel: channel}
    end

    def public_video_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://kazarma/-/bob",
            "https://www.w3.org/ns/activitystreams#Public"
          ],
          "actor" => "http://pleroma/pub/actors/alice"
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Video",
            "id" => "note_id",
            "actor" => "http://pleroma/pub/actors/alice",
            "attributedTo" => [
              %{"type" => "Person", "id" => "http://pleroma/pub/actors/alice"},
              %{"type" => "Group", "id" => "http://pleroma/pub/actors/channel"}
            ],
            "content" => "Video description",
            "name" => "Video name",
            "duration" => 42,
            "url" => [],
            "icon" => [
              %{
                "width" => 150,
                "url" => "https://via.placeholder.com/150"
              }
            ],
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil
          }
        }
      }
    end

    test "receiving a public note forwards it to the puppet's timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_channel___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:upload, fn _blob,
                            [filename: "150", mimetype: "application/octet-stream"],
                            [user_id: "@_ap_channel___pleroma:kazarma"] ->
        {:ok, "mxc://server/media_id"}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "body" =>
                                      "### Video name\n\nnote_id\n\n> Video description\n \uFEFF",
                                    "format" => "org.matrix.custom.html",
                                    "formatted_body" =>
                                      "<h3>Video name</h3>\n<a href=\"note_id\">\n  <img src=\"mxc://server/media_id\">\n</a>\n<p>\n  Video description\n</p>\n",
                                    "msgtype" => "m.text"
                                  },
                                  [user_id: "@_ap_channel___pleroma:kazarma"] ->
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

      assert :ok = handle_activity(public_video_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "activity handler (handle_activity/1) for public Page" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Alice",
            "preferredUsername" => "alice",
            "url" => "http://lemmy/u/alice",
            "id" => "http://lemmy/u/alice",
            "username" => "alice@lemmy"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://lemmy/u/alice"
        })

      {:ok, community} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Group",
            "name" => "Community",
            "preferredUsername" => "community",
            "url" => "http://lemmy/c/community",
            "id" => "http://lemmy/c/community",
            "username" => "community@lemmy"
          },
          "local" => false,
          "public" => true,
          "actor" => "http://lemmy/c/community"
        })

      {:ok, actor: actor, community: community}
    end

    def public_page_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://lemmy/c/community",
            "https://www.w3.org/ns/activitystreams#Public"
          ],
          "cc" => [],
          "actor" => "http://lemmy/u/alice"
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Page",
            "id" => "page_id",
            "actor" => "http://lemmy/u/alice",
            "attributedTo" => "http://lemmy/u/alice",
            "content" => "<p>Page description</p>\n",
            "name" => "Page title",
            "mediaType" => "text/html",
            "source" => %{
              "content" => "Page description",
              "mediaType" => "text/markdown"
            },
            "audience" => ["http://lemmy/c/community"],
            "sensitive" => false
          }
        }
      }
    end

    def public_page_with_link_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://lemmy/c/community",
            "https://www.w3.org/ns/activitystreams#Public"
          ],
          "cc" => [],
          "actor" => "http://lemmy/u/alice"
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Page",
            "id" => "page_id",
            "actor" => "http://lemmy/u/alice",
            "attributedTo" => "http://lemmy/u/alice",
            "name" => "Page title",
            "attachment" => [%{"type" => "Link", "url" => [%{"href" => "https://kazar.ma/"}]}],
            "audience" => ["http://lemmy/c/community"],
            "sensitive" => false
          }
        }
      }
    end

    def public_page_with_link_and_description_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://lemmy/c/community",
            "https://www.w3.org/ns/activitystreams#Public"
          ],
          "cc" => [],
          "actor" => "http://lemmy/u/alice"
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Page",
            "id" => "page_id",
            "actor" => "http://lemmy/u/alice",
            "attributedTo" => "http://lemmy/u/alice",
            "content" => "<p>Page description</p>\n",
            "name" => "Page title",
            "mediaType" => "text/html",
            "source" => %{
              "content" => "Page description",
              "mediaType" => "text/markdown"
            },
            "attachment" => [%{"type" => "Link", "url" => [%{"href" => "https://kazar.ma/"}]}],
            "audience" => ["http://lemmy/c/community"],
            "sensitive" => false
          }
        }
      }
    end

    test "receiving a public page forwards it to the puppet's timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___lemmy:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "body" => "Page title\n\nPage description \uFEFF",
                                    "format" => "org.matrix.custom.html",
                                    "formatted_body" =>
                                      "<h3>Page title</h3><p>Page description</p>\n",
                                    "msgtype" => "m.text"
                                  },
                                  [user_id: "@_ap_alice___lemmy:kazarma"] ->
        {:ok, "event_id"}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://lemmy/c/community",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_community___lemmy:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_page_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "page_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "receiving a public page with link forwards it to the puppet's timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___lemmy:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "body" => "Page title\nhttps://kazar.ma/ \uFEFF",
                                    "format" => "org.matrix.custom.html",
                                    "formatted_body" =>
                                      "<a href=\"https://kazar.ma/\"><h3>Page title</h3></a>",
                                    "msgtype" => "m.text"
                                  },
                                  [user_id: "@_ap_alice___lemmy:kazarma"] ->
        {:ok, "event_id"}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://lemmy/c/community",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_community___lemmy:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_page_with_link_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "page_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "receiving a public page with link and description forwards it to the puppet's timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___lemmy:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  %{
                                    "body" =>
                                      "Page title\nhttps://kazar.ma/\n\nPage description \uFEFF",
                                    "format" => "org.matrix.custom.html",
                                    "formatted_body" =>
                                      "<a href=\"https://kazar.ma/\"><h3>Page title</h3></a><p>Page description</p>\n",
                                    "msgtype" => "m.text"
                                  },
                                  [user_id: "@_ap_alice___lemmy:kazarma"] ->
        {:ok, "event_id"}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://lemmy/c/community",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@_ap_community___lemmy:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_page_with_link_and_description_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "page_id",
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

      {:ok, _relay} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Application",
            "name" => "Kazarma",
            "preferredUsername" => "relay",
            "url" => "http://kazarma/-/relay",
            "id" => "http://kazarma/-/relay",
            "username" => "relay@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/relay"
        })

      {:ok, actor: actor}
    end

    def follow_fixture do
      %{
        data: %{
          "type" => "Follow",
          "id" => "follow_object_id",
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
            "id" => "follow_object_id",
            "object" => "http://kazarma/-/relay"
          }
        }
      }
    end

    test "following the relay actor makes it accept, follow back and creates the actor room" do
      Kazarma.Matrix.TestClient
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
              "name" => "Kazarma",
              "preferredUsername" => "relay",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma",
            deactivated: false
          },
          object: "follow_object_id",
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)
      |> expect(:follow, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Kazarma",
              "preferredUsername" => "relay",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma"
          },
          object: %ActivityPub.Actor{
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
          }
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
              "name" => "Kazarma",
              "preferredUsername" => "relay",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma",
            deactivated: false
          },
          object: "follow_object_id",
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)
      |> expect(:follow, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Kazarma",
              "preferredUsername" => "relay",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma"
          },
          object: %ActivityPub.Actor{
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
          }
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
      |> expect(:send_message, fn
        "!room:kazarma",
        %{"body" => "has started bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Kazarma",
              "preferredUsername" => "relay",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma",
            deactivated: false
          },
          object: "follow_object_id",
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)
      |> expect(:follow, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Kazarma",
              "preferredUsername" => "relay",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma"
          },
          object: %ActivityPub.Actor{
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
          }
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

      {:ok, relay} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Application",
            "name" => "Kazarma",
            "preferredUsername" => "relay",
            "url" => "http://kazarma/-/relay",
            "id" => "http://kazarma/-/relay",
            "username" => "relay@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/relay"
        })

      {:ok, actor: actor, relay: relay}
    end

    def follow_fixture do
      %{
        data: %{
          "type" => "Follow",
          "id" => "follow_object_id",
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
            "id" => "follow_object_id",
            "object" => "http://kazarma/-/relay"
          }
        }
      }
    end

    test "unfollowing the relay actor makes it unfollow back and deactivates the actor room" do
      Kazarma.Matrix.TestClient
      |> expect(:send_message, fn
        "!room:kazarma",
        %{"body" => "has stopped bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:unfollow, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/relay",
              "name" => "Kazarma",
              "preferredUsername" => "relay",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/relay",
            username: "relay@kazarma"
          },
          object: %ActivityPub.Actor{
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
          }
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
