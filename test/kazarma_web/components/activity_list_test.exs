# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarmaweb.Components.ActivityListTests do
  @moduledoc """
  Component testing renderings of the activitylist tests components
  """
  use Kazarma.DataCase

  import Phoenix.LiveViewTest
  alias KazarmaWeb.Components.ActivityList

  describe "activity_list component" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, %ActivityPub.Object{data: data}} =
        ActivityPub.Object.do_insert(%{
          local: true,
          deactivated: false,
          username: "alice@kazarma",
          ap_id: "http://kazarma/-/alice",
          data: %{
            "preferredUsername" => "alice",
            "id" => "http://kazarma/-/alice",
            "type" => "Person",
            "name" => "Alice",
            "icon" => %{
              "type" => "Image",
              "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
            },
            "followers" => "http://kazarma/-/alice/followers",
            "following" => "http://kazarma/-/alice/following",
            "inbox" => "http://kazarma/-/alice/inbox",
            "outbox" => "http://kazarma/-/alice/outbox",
            "manuallyApprovesFollowers" => false,
            endpoints: %{
              "sharedInbox" => "http://kazarma/shared_inbox"
            }
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
          "local" => false,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
        })

      {:ok, grandparent_object} =
        ActivityPub.Object.do_insert(%{
          "local" => true,
          "data" => %{
            "type" => "Note",
            "content" =>
              ~S(<p><span class="h-card"><a href="http://kazarma/-/bob" class="u-url mention">@<span>bob@kazarma.kazarma.local</span></a></span> hello</p>),
            "source" => "@bob@kazarma.kazarma.local hello",
            "id" => "grand_parent_note_id",
            "actor" => "http://kazarma/-/alice",
            "conversation" => "http://kazarma/-/pub/contexts/context",
            "attachment" => nil,
            "published" => "2018-05-11T16:23:37Z"
          }
        })

      {:ok, parent_object} =
        ActivityPub.Object.do_insert(%{
          "local" => true,
          "data" => %{
            "type" => "Note",
            "content" =>
              ~S(<p><span class="h-card"><a href="http://kazarma/-/bob" class="u-url mention">@<span>bob@kazarma.kazarma.local</span></a></span> hello</p>),
            "source" => "@bob@kazarma.kazarma.local hello",
            "id" => "parent_note_id",
            "actor" => "http://kazarma/-/alice",
            "conversation" => "http://kazarma/-/pub/contexts/context",
            "attachment" => nil,
            "inReplyTo" => "grand_parent_note_id",
            "published" => "2019-07-09T10:56:59.884187Z",
            "tag" => [
              %{
                "type" => "Mention",
                "href" => "http://kazarma/-/bob",
                "name" => "@bob@kazarma.kazarma.local"
              }
            ]
          }
        })

      {:ok, note_object} =
        ActivityPub.Object.do_insert(%{
          "local" => true,
          "data" => %{
            "type" => "Note",
            "content" =>
              ~S(<p><span class="h-card"><a href="http://kazarma/-/bob" class="u-url mention">@<span>bob@kazarma.kazarma.local</span></a></span> hello</p>),
            "source" => "@bob@kazarma.kazarma.local hello",
            "id" => "note_id",
            "actor" => "http://kazarma/-/alice",
            "conversation" => "http://kazarma/-/pub/contexts/context",
            "attachment" => nil,
            "inReplyTo" => "parent_note_id",
            "published" => "2019-07-14T06:40:41.376405Z"
          }
        })

      {:ok, non_note_object} =
        ActivityPub.Object.do_insert(%{
          "local" => true,
          "data" => %{
            "type" => "Wallah",
            "content" =>
              ~S(<p><span class="h-card"><a href="http://kazarma/-/bob" class="u-url mention">@<span>bob@kazarma.kazarma.local</span></a></span> hello</p>),
            "source" => "@bob@kazarma.kazarma.local hello",
            "id" => "random_id",
            "actor" => "http://kazarma/-/alice",
            "attachment" => nil,
            "inReplyTo" => "grand_parent_note_id",
            "published" => "2019-07-14T06:40:41.376405Z"
          }
        })

      {:ok,
       %{
         actor_data: data,
         parent_object: parent_object,
         note_object: note_object,
         grand_parent_object: grandparent_object,
         non_note_object: non_note_object
       }}
    end

    test "displays note objects properly", %{
      actor_data: actor_data,
      parent_object: parent_object,
      note_object: note_object,
      grand_parent_object: grandparent_object
    } do
      render_component(&ActivityList.show/1, %{
        previous_objects: [grandparent_object],
        next_objects: [note_object],
        object: parent_object,
        actor: %ActivityPub.Actor{data: actor_data, local: true, username: "alice@kazarma"},
        socket: %{}
      })
      |> assert_html_include("div#note_id")
      |> assert_html_include("div#parent_note_id")
      |> assert_html_include("div#grand_parent_note_id")
      |> assert_html_include(
        "h1 a",
        3,
        %{href: "/-/alice", title: "@alice:kazarma"},
        "Alice"
      )
      |> assert_html_include("div.avatar img", 3, %{
        src: "http://matrix/_matrix/media/r0/download/server/image_id",
        alt: "Alice's avatar"
      })
      |> assert_html_include("svg.reply_icon")
      |> assert_html_include("svg.replied_icon")
      |> assert_html_include("a", 1, %{href: "/-/alice/note/" <> note_object.id})
      |> assert_html_include("a", 1, %{href: "/-/alice/note/" <> parent_object.id})
      |> assert_html_include("a", 1, %{href: "/-/alice/note/" <> grandparent_object.id})
    end

    test "displays non note object properly", %{
      actor_data: actor_data,
      non_note_object: non_note_object
    } do
      render_component(&ActivityList.show/1, %{
        previous_objects: [non_note_object],
        next_objects: [non_note_object],
        object: non_note_object,
        actor: %ActivityPub.Actor{data: actor_data, local: true, username: "alice@kazarma"},
        socket: %{}
      })
      |> assert_html_include("svg.reply_icon")
      |> assert_html_include("svg.replied_icon")
      |> assert_html_include("div.card-body a", 3, %{href: "random_id", title: "Open"}, "Open")
    end
  end
end
