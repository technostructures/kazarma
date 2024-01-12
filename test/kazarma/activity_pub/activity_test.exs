# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.ActivityTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter

  describe "activity handler (handle_activity/1) for Delete activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def delete_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "delete_object_id",
          "actor" => "http://kazarma/-/bob",
          "type" => "Delete",
          "to" => ["http://pleroma/pub/actors/alice"],
          "object" => "http://pleroma/pub/transactions/object_id"
        }
      }
    end

    setup do
      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://kazarma/-/bob",
            "id" => "http://kazarma/-/bob",
            "username" => "bob@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
        })

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "http://pleroma/pub/transactions/object_id",
          room_id: "!room:kazarma"
        })

      :ok
    end

    test "when receiving a Delete activity for an existing object, gets the corresponding ids and forwards the redact event" do
      Kazarma.Matrix.TestClient
      |> expect(:redact_message, fn "!room:kazarma", "local_id", nil, user_id: "@bob:kazarma" ->
        {:ok, "delete_event_id"}
      end)

      assert :ok == handle_activity(delete_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "http://pleroma/pub/transactions/object_id",
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

  describe "Convert files" do
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

    def public_note_fixture_with_attachment do
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
              ~S(<p><span class="h-card"><a href="http://kazarma/-/bob" class="u-url mention">@<span>bob@kazarma.kazarma.local</span></a></span> hello</p>),
            "source" => "@bob@kazarma.kazarma.local hello",
            "id" => "note_id",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => [
              %{
                "mediaType" => "image/jpeg",
                "name" => "aabbccddeeffgg",
                "type" => "Document",
                "url" => [
                  %{
                    "href" => "https://example.com/",
                    "mediaType" => "image/jpeg",
                    "type" => "Link"
                  }
                ]
              }
            ],
            "attributedTo" => "http://kazarma/-/bob",
            "content" => ""
          }
        }
      }
    end

    test "it converts attachment" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{
          "body" =>
            "@bob@kazarma.kazarma.local hello\nhttp://matrix/_matrix/media/r0/download/server/image_id \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "<img src=\"http://matrix/_matrix/media/r0/download/server/image_id\" title=\"aabbccddeeffgg\">",
          "msgtype" => "m.text"
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "event_id"}
      end)
      |> expect(:upload, fn
        "<!doctype html>\n<html>\n<head>\n    <title>Example Domain</title>\n\n    <meta charset=\"utf-8\" />\n    <meta http-equiv=\"Content-type\" content=\"text/html; charset=utf-8\" />\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n    <style type=\"text/css\">\n    body {\n        background-color: #f0f0f2;\n        margin: 0;\n        padding: 0;\n        font-family: -apple-system, system-ui, BlinkMacSystemFont, \"Segoe UI\", \"Open Sans\", \"Helvetica Neue\", Helvetica, Arial, sans-serif;\n        \n    }\n    div {\n        width: 600px;\n        margin: 5em auto;\n        padding: 2em;\n        background-color: #fdfdff;\n        border-radius: 0.5em;\n        box-shadow: 2px 3px 7px 2px rgba(0,0,0,0.02);\n    }\n    a:link, a:visited {\n        color: #38488f;\n        text-decoration: none;\n    }\n    @media (max-width: 700px) {\n        div {\n            margin: 0 auto;\n            width: auto;\n        }\n    }\n    </style>    \n</head>\n\n<body>\n<div>\n    <h1>Example Domain</h1>\n    <p>This domain is for use in illustrative examples in documents. You may use this\n    domain in literature without prior coordination or asking for permission.</p>\n    <p><a href=\"https://www.iana.org/domains/example\">More information...</a></p>\n</div>\n</body>\n</html>\n",
        [filename: "example.com", mimetype: "application/octet-stream"],
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "http://matrix/_matrix/media/r0/download/server/image_id"}
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

      assert :ok = handle_activity(public_note_fixture_with_attachment())
    end
  end

  describe "Content conversion" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://kazarma/-/bob",
            "id" => "http://kazarma/-/bob",
            "username" => "bob@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
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

      {:ok, actor: actor}
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
              ~S(<p><span class="h-card"><a href="http://kazarma/-/bob" class="u-url mention">@<span>bob@kazarma.kazarma.local</span></a></span> hello</p>),
            "source" => "@bob@kazarma.kazarma.local hello",
            "id" => "note_id",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil,
            "tag" => [
              %{
                "type" => "Mention",
                "href" => "http://kazarma/-/bob",
                "name" => "@bob@kazarma.kazarma.local"
              }
            ]
          }
        }
      }
    end

    test "it converts mentions" do
      Kazarma.Matrix.TestClient
      |> expect(:join, fn "!room:kazarma", user_id: "@_ap_alice___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:send_state_event, fn
        "!room:kazarma",
        "m.room.member",
        "@_ap_bob___kazarma.kazarma.local:kazarma",
        %{"membership" => "invite"},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, "!invite_event"}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        %{
          "body" => "@bob:kazarma hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "<p><a href=\"https://matrix.to/#/@bob:kazarma\">Bob</a> hello</p>",
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

      assert :ok == handle_activity(public_note_fixture_with_mention())
    end
  end

  describe "activity handler (handle_activity/1) for Block activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def block_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "block_object_id",
          "type" => "Block",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => "http://kazarma/-/bob"
        }
      }
    end

    def unblock_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "unblock_object_id",
          "type" => "Undo",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => %{
            "type" => "Block",
            "object" => "http://kazarma/-/bob"
          }
        }
      }
    end

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "local_id",
          remote_id: "http://pleroma/pub/actors/alice",
          data: %{
            "type" => "ap_user",
            "matrix_id" => "@_ap_alice___pleroma:kazarma"
          }
        })

      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://kazarma/-/bob",
            "id" => "http://kazarma/-/bob",
            "username" => "bob@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
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

      {:ok, actor: actor}
    end

    test "when receiving a Block activity for a Matrix user it ignores the user and bans them from the actor room" do
      Kazarma.Matrix.TestClient
      |> expect(:get_data, fn
        "@_ap_alice___pleroma:kazarma",
        "m.ignored_user_list",
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, %{}}
      end)
      |> expect(:put_data, fn
        "@_ap_alice___pleroma:kazarma",
        "m.ignored_user_list",
        %{"@bob:kazarma" => %{}},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)
      |> expect(:send_state_event, fn "local_id",
                                      "m.room.member",
                                      "@bob:kazarma",
                                      %{"membership" => "ban"},
                                      [user_id: "@_ap_alice___pleroma:kazarma"] ->
        :ok
      end)

      assert :ok == handle_activity(block_fixture())
    end

    test "when receiving a Undo/Block activity for a Matrix user it unignores the user and unbans them from the actor room" do
      Kazarma.Matrix.TestClient
      |> expect(:get_data, fn
        "@_ap_alice___pleroma:kazarma",
        "m.ignored_user_list",
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, %{"@bob:kazarma" => %{}}}
      end)
      |> expect(:put_data, fn
        "@_ap_alice___pleroma:kazarma",
        "m.ignored_user_list",
        %{},
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          :ok
      end)
      |> expect(:send_state_event, fn "local_id",
                                      "m.room.member",
                                      "@bob:kazarma",
                                      %{"membership" => "leave"},
                                      [user_id: "@_ap_alice___pleroma:kazarma"] ->
        :ok
      end)

      assert :ok == handle_activity(unblock_fixture())
    end
  end

  describe "activity handler (handle_activity/1) for Follow activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
          "data" => %{
            "type" => "Person",
            "name" => "Bob",
            "preferredUsername" => "bob",
            "url" => "http://kazarma/-/bob",
            "id" => "http://kazarma/-/bob",
            "username" => "bob@kazarma"
          },
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
        })

      :ok
    end

    def follow_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "follow_object_id",
          "type" => "Follow",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => "http://kazarma/-/bob"
        }
      }
    end

    def unfollow_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "unfollow_object_id",
          "type" => "Undo",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => %{
            "type" => "Follow",
            "object" => "http://kazarma/-/bob"
          }
        }
      }
    end

    test "when receiving a Follow activity for a Matrix user it accepts the follow" do
      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %{
            data: %{
              "id" => "http://kazarma/-/bob",
              "name" => "Bob",
              "preferredUsername" => "bob",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/bob",
            username: "bob@kazarma",
            deactivated: false
          },
          object: "follow_object_id",
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)

      assert :ok == handle_activity(follow_fixture())
    end

    test "when receiving a Undo/Follow activity for a Matrix user it does nothing" do
      assert :ok == handle_activity(unfollow_fixture())
    end
  end
end
