# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomTypes.ActorOutboxTest do
  @moduledoc """
  Transaction tests for events received from the Matrix server.
  We use existing Pleroma and Matrix accounts so we can create corresponding
  puppets.
  """
  use Kazarma.DataCase, async: false

  import Kazarma.ActivityPub.Adapter
  import Kazarma.Matrix.Transaction
  import Kazarma.MatrixMocks
  alias Kazarma.Bridge
  alias MatrixAppService.Event

  # Those are accounts created on public ActivityPub instances
  @pleroma_user_server "pleroma.interhacker.space"
  @pleroma_user_name "pierre"
  @pleroma_user_displayname "Pierre"
  @pleroma_user_full_username "pierre@pleroma.interhacker.space"
  @pleroma_user_ap_id "https://pleroma.interhacker.space/users/pierre"
  @pleroma_puppet_username "#{@pleroma_user_name}.#{@pleroma_user_server}"
  @pleroma_puppet_address "@#{@pleroma_puppet_username}:kazarma"

  setup :config_public_bridge

  describe "When sending a message to a timeline room" do
    @describetag :external

    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
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

      {:ok, pierre} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => @pleroma_user_displayname,
            "preferredUsername" => @pleroma_user_name,
            "url" => @pleroma_user_ap_id,
            "id" => @pleroma_user_ap_id,
            "username" => @pleroma_user_full_username
          },
          "local" => false,
          "public" => true,
          "actor" => @pleroma_user_ap_id
        })

      pierre
      |> ActivityPub.Actor.format_remote_actor()
      |> ActivityPub.Actor.set_cache()

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: @pleroma_puppet_username,
          remote_id: @pleroma_user_ap_id
        })

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
      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            ap_id: "http://kazarma/-/bob",
            data: _,
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
                "name" => "@#{@pleroma_user_name}",
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
      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@bob.matrix:kazarma",
          remote_id: "http://kazarma/matrix/bob",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/matrix/bob",
              "preferredUsername" => "bob.matrix",
              "name" => "Bob",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/avatar"},
              "endpoints" => %{"sharedInbox" => "http://kazarma/shared_inbox"},
              "capabilities" => %{"acceptsChatMessages" => true},
              "followers" => "http://kazarma/matrix/bob/followers",
              "following" => "http://kazarma/matrix/bob/following",
              "inbox" => "http://kazarma/matrix/bob/inbox",
              "manuallyApprovesFollowers" => false,
              "outbox" => "http://kazarma/matrix/bob/outbox",
              "type" => "Person"
            },
            "keys" => keys
          }
        })

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

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@alice.pleroma:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
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
            "http://kazarma/kazarma/bob",
            "https://www.w3.org/ns/activitystreams#Public"
          ]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "content" =>
              "<p><span class=\"h-card\"><a href=\"http://kazarma/matrix/bob\" class=\"u-url mention\">@<span>bob.matrix</span></a></span> hello</p>",
            "id" => "note_id",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil,
            "tag" => [
              %{
                "href" => "http://kazarma/matrix/bob",
                "name" => "@bob.matrix@kazarma",
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
      |> expect_join("@alice.pleroma:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        {"hello \uFEFF", "hello"},
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert {:ok, _} = handle_activity(public_note_fixture())

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
      |> expect_join("@alice.pleroma:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        %{
          "body" => "hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "hello",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert {:ok, _} = handle_activity(public_note_fixture_with_content())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "note_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "receiving a public note with a mention of Matrix user mentions them" do
      Kazarma.Matrix.TestClient
      |> expect_join("@alice.pleroma:kazarma", "!room:kazarma")
      |> expect_send_state_event(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        "m.room.member",
        "@bob.matrix:kazarma",
        %{"membership" => "invite"},
        "invite_id"
      )
      |> expect_send_message(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        %{
          "body" => "@bob.matrix hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "<p><a href=\"https://matrix.to/#/@bob.matrix:kazarma\">Bob</a> hello</p>",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert {:ok, _} = handle_activity(public_note_fixture_with_mention())

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

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@bob.pleroma:kazarma",
          remote_id: "http://pleroma/pub/actors/bob"
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
      |> expect_join("@bob.pleroma:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@bob.pleroma:kazarma",
        "!room:kazarma",
        %{
          "msgtype" => "m.text",
          "body" => "hello \uFEFF",
          "m.relates_to" => %{
            "m.in_reply_to" => %{
              "event_id" => "local_id"
            }
          }
        },
        "reply_id"
      )

      %{
        local_id: "local_id",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/bob",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@bob.pleroma:kazarma"
        }
      }
      |> Bridge.create_room()

      assert {:ok, _} = handle_activity(public_note_with_reply_fixture())

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
          "matrix_id" => "@alice.pleroma:kazarma"
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

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@alice.pleroma:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
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

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@channel.pleroma:kazarma",
          remote_id: "http://pleroma/pub/actors/channel"
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
                "url" => "https://example.com"
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
      |> expect_join("@channel.pleroma:kazarma", "!room:kazarma")
      |> expect_upload_something(
        "@channel.pleroma:kazarma",
        "mxc://server/media_id"
      )
      |> expect_send_message(
        "@channel.pleroma:kazarma",
        "!room:kazarma",
        %{
          "body" => "### Video name\n\nnote_id\n\n> Video description\n \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "<h3>Video name</h3>\n<a href=\"note_id\">\n  <img src=\"mxc://server/media_id\">\n</a>\n<p>\n  Video description\n</p>\n",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma:kazarma"
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

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@alice.lemmy:kazarma",
          remote_id: "http://lemmy/u/alice"
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
      |> expect_join("@alice.lemmy:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@alice.lemmy:kazarma",
        "!room:kazarma",
        %{
          "body" => "Page title\n\nPage description \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "<h3>Page title</h3><p>Page description</p>\n",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://lemmy/c/community",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@community.lemmy:kazarma"
        }
      }
      |> Bridge.create_room()

      assert {:ok, _} = handle_activity(public_page_fixture())

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
      |> expect_join("@alice.lemmy:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@alice.lemmy:kazarma",
        "!room:kazarma",
        %{
          "body" => "Page title\nhttps://kazar.ma/ \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "<a href=\"https://kazar.ma/\"><h3>Page title</h3></a>",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://lemmy/c/community",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@community.lemmy:kazarma"
        }
      }
      |> Bridge.create_room()

      assert {:ok, _} = handle_activity(public_page_with_link_fixture())

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
      |> expect_join("@alice.lemmy:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@alice.lemmy:kazarma",
        "!room:kazarma",
        %{
          "body" => "Page title\nhttps://kazar.ma/\n\nPage description \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "<a href=\"https://kazar.ma/\"><h3>Page title</h3></a><p>Page description</p>\n",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://lemmy/c/community",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@community.lemmy:kazarma"
        }
      }
      |> Bridge.create_room()

      assert {:ok, _} = handle_activity(public_page_with_link_and_description_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "event_id",
                 remote_id: "page_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end

  describe "When an actor follows the activity bot actor" do
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

      # {:ok, _user} =
      #   Kazarma.Bridge.create_user(%{
      #     local_id: "@alice.pleroma:kazarma",
      #     remote_id: "http://pleroma/pub/actors/alice"
      #   })

      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@activity_bridge:kazarma",
          remote_id: "http://kazarma/-/activity_bridge",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/-/activity_bridge",
              "preferredUsername" => "activity_bridge",
              "name" => "Kazarma",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/avatar"},
              "type" => "Application"
            },
            "keys" => keys
          }
        })

      {:ok, actor: actor}
    end

    def follow_fixture do
      %{
        data: %{
          "type" => "Follow",
          "id" => "follow_object_id",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => "http://kazarma/-/activity_bridge"
        }
      }
    end

    test "following the activity bot actor makes it accept, follow back and creates the actor room" do
      Kazarma.Matrix.TestClient
      |> expect_register(%{
        username: "alice.pleroma",
        matrix_id: "@alice.pleroma:kazarma",
        displayname: "Alice"
      })
      |> expect_create_room(
        "@alice.pleroma:kazarma",
        [
          visibility: :public,
          name: "Alice",
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          room_alias_name: "alice.pleroma",
          initial_state: [
            %{content: %{guest_access: :can_join}, type: "m.room.guest_access"},
            %{content: %{history_visibility: :world_readable}, type: "m.room.history_visibility"}
          ]
        ],
        "!room:kazarma"
      )
      |> expect_send_message(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        %{"body" => "has started bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        nil
      )

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/activity_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "activity_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/activity_bridge",
            username: "activity_bridge@kazarma",
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
              "id" => "http://kazarma/-/activity_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "activity_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/activity_bridge",
            username: "activity_bridge@kazarma"
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
                 data: %{"matrix_id" => "@alice.pleroma:kazarma", "type" => "ap_user"},
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end

    test "following the activity bot actor makes it accept, follow back and gets the actor room by alias if it already exists" do
      Kazarma.Matrix.TestClient
      |> expect_register(%{
        username: "alice.pleroma",
        matrix_id: "@alice.pleroma:kazarma",
        displayname: "Alice"
      })
      |> expect_create_room_existing("@alice.pleroma:kazarma",
        visibility: :public,
        name: "Alice",
        topic: nil,
        is_direct: false,
        invite: [],
        room_version: "5",
        room_alias_name: "alice.pleroma",
        initial_state: [
          %{content: %{guest_access: :can_join}, type: "m.room.guest_access"},
          %{content: %{history_visibility: :world_readable}, type: "m.room.history_visibility"}
        ]
      )
      |> expect_get_alias("#alice.pleroma:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        %{"body" => "has started bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        "event_id"
      )

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/activity_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "activity_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/activity_bridge",
            username: "activity_bridge@kazarma",
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
              "id" => "http://kazarma/-/activity_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "activity_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/activity_bridge",
            username: "activity_bridge@kazarma"
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
                 data: %{"matrix_id" => "@alice.pleroma:kazarma", "type" => "ap_user"},
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end

    test "following the activity bot actor makes it accept, follow back and starts bridging again is activity bot had previously been unfollowed" do
      Kazarma.Matrix.TestClient
      |> expect_register(%{
        username: "alice.pleroma",
        matrix_id: "@alice.pleroma:kazarma",
        displayname: "Alice"
      })
      |> expect_send_message(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        %{"body" => "has started bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        "event_id"
      )

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %{
            data: %{
              "id" => "http://kazarma/-/activity_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "activity_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/activity_bridge",
            username: "activity_bridge@kazarma",
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
              "id" => "http://kazarma/-/activity_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "activity_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/activity_bridge",
            username: "activity_bridge@kazarma"
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
          data: %{"type" => "deactivated_ap_user", "matrix_id" => "@alice.pleroma:kazarma"}
        })

      assert :ok = handle_activity(follow_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{"matrix_id" => "@alice.pleroma:kazarma", "type" => "ap_user"},
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end
  end

  describe "When an actor unfollows the activity bot actor" do
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

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@alice.pleroma:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@activity_bridge:kazarma",
          remote_id: "http://kazarma/-/activity_bridge",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/-/activity_bridge",
              "preferredUsername" => "activity_bridge",
              "name" => "Kazarma",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/avatar"},
              "type" => "Application"
            },
            "keys" => keys
          }
        })

      {:ok, actor: actor}
    end

    def unfollow_fixture do
      %{
        data: %{
          "type" => "Undo",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => %{
            "type" => "Follow",
            "id" => "follow_object_id",
            "object" => "http://kazarma/-/activity_bridge"
          }
        }
      }
    end

    test "unfollowing the activity bot actor makes it unfollow back and deactivates the actor room" do
      Kazarma.Matrix.TestClient
      |> expect_send_message(
        "@alice.pleroma:kazarma",
        "!room:kazarma",
        %{"body" => "has stopped bridging their public activity \uFEFF", "msgtype" => "m.emote"},
        "event_id"
      )

      Kazarma.ActivityPub.TestServer
      |> expect(:unfollow, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/activity_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "activity_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/activity_bridge",
            username: "activity_bridge@kazarma"
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
          data: %{"type" => "ap_user", "matrix_id" => "@alice.pleroma:kazarma"}
        })

      assert :ok = handle_activity(unfollow_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{
                   "matrix_id" => "@alice.pleroma:kazarma",
                   "type" => "deactivated_ap_user"
                 },
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_rooms()
    end
  end
end
