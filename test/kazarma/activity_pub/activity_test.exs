# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.ActivityTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "Convert files" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      alice = create_ap_user_alice()

      {:ok, actor: alice}
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
            "source" => "@bob@kazarma hello",
            "id" => "note_id",
            "actor" => "http://pleroma.com/pub/actors/alice",
            "conversation" => "http://pleroma.com/pub/contexts/context",
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
      |> expect_join("@alice.pleroma.com:kazarma", "!room:kazarma")
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        %{
          "body" =>
            "@bob@kazarma hello\nhttp://matrix/_matrix/media/r0/download/server/image_id \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "<img src=\"http://matrix/_matrix/media/r0/download/server/image_id\" title=\"aabbccddeeffgg\">",
          "msgtype" => "m.text"
        },
        "event_id"
      )
      |> expect_upload(
        "@alice.pleroma.com:kazarma",
        "<!doctype html><html lang=\"en\"><head><title>Example Domain</title><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><style>body{background:#eee;width:60vw;margin:15vh auto;font-family:system-ui,sans-serif}h1{font-size:1.5em}div{opacity:0.8}a:link,a:visited{color:#348}</style><body><div><h1>Example Domain</h1><p>This domain is for use in documentation examples without needing permission. Avoid use in operations.<p><a href=\"https://iana.org/domains/example\">Learn more</a></div></body></html>\n",
        [filename: "example.com", mimetype: "application/octet-stream"],
        "http://matrix/_matrix/media/r0/download/server/image_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma.com/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma.com:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok = handle_activity(public_note_fixture_with_attachment())
    end
  end

  describe "Mentions conversion for local user" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      alice = create_ap_user_alice()
      create_local_matrix_user_bob()

      {:ok, actor: alice}
    end

    def public_note_fixture_with_mention_to_local do
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
              ~S(<p><span class="h-card"><a href="http://kazarma/-/bob" class="u-url mention">@<span>bob@kazarma</span></a></span> hello</p>),
            "source" => "@bob@kazarma hello",
            "id" => "note_id",
            "actor" => "http://pleroma.com/pub/actors/alice",
            "conversation" => "http://pleroma.com/pub/contexts/context",
            "attachment" => nil,
            "tag" => [
              %{
                "type" => "Mention",
                "href" => "http://kazarma/-/bob",
                "name" => "@bob@kazarma"
              }
            ]
          }
        }
      }
    end

    test "it converts mentions" do
      Kazarma.Matrix.TestClient
      |> expect_join("@alice.pleroma.com:kazarma", "!room:kazarma")
      |> expect_send_state_event(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        "m.room.member",
        "@bob:kazarma",
        %{"membership" => "invite"},
        "!invite_event"
      )
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        %{
          "body" => "@bob:kazarma hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "<p><a href=\"https://matrix.to/#/@bob:kazarma\">Bob</a> hello</p>",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma.com/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma.com:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok == handle_activity(public_note_fixture_with_mention_to_local())
    end
  end

  describe "Mentions conversion for remote user" do
    setup :set_mox_from_context
    setup :verify_on_exit!
    setup :config_public_bridge

    setup do
      alice = create_ap_user_alice()
      create_remote_matrix_user_david()

      {:ok, actor: alice}
    end

    def public_note_fixture_with_mention_to_remote do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://kazarma/matrix.org/david",
            "https://www.w3.org/ns/activitystreams#Public"
          ]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "content" =>
              ~S(@<a href=\"http://david.matrix.org@kazarma.kazarma\" rel=\"ugc\">david.matrix.org@kazarma.kazarma</a> hello</p>),
            "source" => %{
              "content" => "@david.matrix.org@kazarma.kazarma hello",
              "mediaType" => "text/plain"
            },
            "id" => "note_id",
            "actor" => "http://pleroma.com/pub/actors/alice",
            "conversation" => "http://pleroma.com/pub/contexts/context",
            "attachment" => nil,
            "tag" => [
              %{
                "type" => "Mention",
                "href" => "http://kazarma/matrix.org/david",
                "name" => "@david.matrix.org@kazarma.kazarma"
              }
            ]
          }
        }
      }
    end

    test "it converts mentions" do
      Kazarma.Matrix.TestClient
      |> expect_join("@alice.pleroma.com:kazarma", "!room:kazarma")
      |> expect_send_state_event(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        "m.room.member",
        "@david:matrix.org",
        %{"membership" => "invite"},
        "!invite_event"
      )
      |> expect_send_message(
        "@alice.pleroma.com:kazarma",
        "!room:kazarma",
        %{
          "body" => "@david:matrix.org hello \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" =>
            "@<a href=\"https://matrix.to/#/@david:matrix.org\">David</a> hello",
          "msgtype" => "m.text"
        },
        "event_id"
      )

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma.com/pub/actors/alice",
        data: %{
          "type" => "ap_user",
          "matrix_id" => "@alice.pleroma.com:kazarma"
        }
      }
      |> Bridge.create_room()

      assert :ok == handle_activity(public_note_fixture_with_mention_to_remote())
    end
  end
end
