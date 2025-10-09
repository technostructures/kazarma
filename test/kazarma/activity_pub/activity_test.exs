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
        "<!doctype html>\n<html>\n<head>\n    <title>Example Domain</title>\n\n    <meta charset=\"utf-8\" />\n    <meta http-equiv=\"Content-type\" content=\"text/html; charset=utf-8\" />\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n    <style type=\"text/css\">\n    body {\n        background-color: #f0f0f2;\n        margin: 0;\n        padding: 0;\n        font-family: -apple-system, system-ui, BlinkMacSystemFont, \"Segoe UI\", \"Open Sans\", \"Helvetica Neue\", Helvetica, Arial, sans-serif;\n        \n    }\n    div {\n        width: 600px;\n        margin: 5em auto;\n        padding: 2em;\n        background-color: #fdfdff;\n        border-radius: 0.5em;\n        box-shadow: 2px 3px 7px 2px rgba(0,0,0,0.02);\n    }\n    a:link, a:visited {\n        color: #38488f;\n        text-decoration: none;\n    }\n    @media (max-width: 700px) {\n        div {\n            margin: 0 auto;\n            width: auto;\n        }\n    }\n    </style>    \n</head>\n\n<body>\n<div>\n    <h1>Example Domain</h1>\n    <p>This domain is for use in illustrative examples in documents. You may use this\n    domain in literature without prior coordination or asking for permission.</p>\n    <p><a href=\"https://www.iana.org/domains/example\">More information...</a></p>\n</div>\n</body>\n</html>\n",
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

  describe "Content conversion" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      alice = create_ap_user_alice()
      create_local_matrix_user_bob()

      {:ok, actor: alice}
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

      assert :ok == handle_activity(public_note_fixture_with_mention())
    end
  end
end
