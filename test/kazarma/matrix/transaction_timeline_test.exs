# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.TransactionTimelineTest do
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
  @pleroma_user_ap_id "https://kiwifarms.cc/users/test_user_bob2"
  @pleroma_puppet_username "_ap_#{@pleroma_user_name}___#{@pleroma_user_server}"
  @pleroma_puppet_address "@#{@pleroma_puppet_username}:kazarma"

  describe "When joining a timeline room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Kazarma.Matrix.Bridge.create_room(%{
          local_id: "!room:kazarma",
          remote_id: @pleroma_user_ap_id,
          data: %{"matrix_id" => @pleroma_puppet_address, "type" => "outbox"}
        })

      :ok
    end

    def joining_event do
      %Event{
        type: "m.room.member",
        content: %{"membership" => "join"},
        room_id: "!room:kazarma",
        state_key: "@alice:kazarma"
      }
    end

    test "it makes the AP puppet follow the AP user" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, fn
        [user_id: @pleroma_puppet_address] ->
          :client_bob
      end)
      |> expect(:get_profile, fn :client_kazarma, "@alice:kazarma" ->
        {:ok, %{"displayname" => "Alice"}}
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
        :client_bob, @pleroma_puppet_address, @pleroma_user_displayname ->
          :ok
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:follow, fn
        %ActivityPub.Actor{
          ap_id: "http://kazarma/pub/actors/alice",
          data: %{
            :endpoints => %{"sharedInbox" => "http://kazarma/pub/shared_inbox"},
            "capabilities" => %{"acceptsChatMessages" => true},
            "followers" => "http://kazarma/pub/actors/alice/followers",
            "followings" => "http://kazarma/pub/actors/alice/following",
            "icon" => nil,
            "id" => "http://kazarma/pub/actors/alice",
            "inbox" => "http://kazarma/pub/actors/alice/inbox",
            "manuallyApprovesFollowers" => false,
            "name" => "Alice",
            "outbox" => "http://kazarma/pub/actors/alice/outbox",
            "preferredUsername" => "alice",
            "type" => "Person"
          },
          deactivated: false,
          id: nil,
          keys: _,
          local: true,
          pointer_id: nil,
          username: "alice@kazarma"
        },
        %ActivityPub.Actor{
          ap_id: "https://kiwifarms.cc/users/test_user_bob2",
          data: %{
            "@context" => [
              "https://www.w3.org/ns/activitystreams",
              "https://kiwifarms.cc/schemas/litepub-0.1.jsonld",
              %{"@language" => "und"}
            ],
            "alsoKnownAs" => [],
            "attachment" => [],
            "capabilities" => %{"acceptsChatMessages" => true},
            "discoverable" => false,
            "endpoints" => %{
              "oauthAuthorizationEndpoint" => "https://kiwifarms.cc/oauth/authorize",
              "oauthRegistrationEndpoint" => "https://kiwifarms.cc/api/v1/apps",
              "oauthTokenEndpoint" => "https://kiwifarms.cc/oauth/token",
              "sharedInbox" => "https://kiwifarms.cc/inbox",
              "uploadMedia" => "https://kiwifarms.cc/api/ap/upload_media"
            },
            "featured" => "https://kiwifarms.cc/users/test_user_bob2/collections/featured",
            "followers" => "https://kiwifarms.cc/users/test_user_bob2/followers",
            "following" => "https://kiwifarms.cc/users/test_user_bob2/following",
            "id" => "https://kiwifarms.cc/users/test_user_bob2",
            "inbox" => "https://kiwifarms.cc/users/test_user_bob2/inbox",
            "manuallyApprovesFollowers" => false,
            "name" => "Bob",
            "outbox" => "https://kiwifarms.cc/users/test_user_bob2/outbox",
            "preferredUsername" => "test_user_bob2",
            "publicKey" => %{
              "id" => "https://kiwifarms.cc/users/test_user_bob2#main-key",
              "owner" => "https://kiwifarms.cc/users/test_user_bob2",
              "publicKeyPem" => _
            },
            "summary" => "",
            "tag" => [],
            "type" => "Person",
            "url" => "https://kiwifarms.cc/users/test_user_bob2",
            "vcard:bday" => nil
          },
          deactivated: false,
          id: _,
          keys: nil,
          local: false,
          pointer_id: nil,
          username: "test_user_bob2@kiwifarms.cc"
        } ->
          {:ok, :activity}
      end)

      assert :ok == new_event(joining_event())
    end
  end

  describe "When sending a message to a timeline room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Kazarma.Matrix.Bridge.create_room(%{
          local_id: "!foo:kazarma",
          remote_id: @pleroma_user_ap_id,
          data: %{"matrix_id" => @pleroma_puppet_address, "type" => "outbox"}
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
      |> expect(:client, fn ->
        :client_kazarma
      end)
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
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
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
          context: _,
          object: %{
            "actor" => "http://kazarma/pub/actors/bob",
            "attributedTo" => "http://kazarma/pub/actors/bob",
            "content" => "hello",
            "context" => _,
            "conversation" => _,
            "tag" => [
              %{
                "href" => "https://kiwifarms.cc/users/test_user_bob2",
                "name" => "@test_user_bob2",
                "type" => "Mention"
              }
            ],
            "to" => [
              "https://www.w3.org/ns/activitystreams#Public",
              "https://kiwifarms.cc/users/test_user_bob2"
            ],
            "type" => "Note"
          },
          to: [
            "https://www.w3.org/ns/activitystreams#Public",
            "https://kiwifarms.cc/users/test_user_bob2"
          ]
        },
        nil ->
          {:ok, :activity}
      end)

      assert :ok == new_event(message_fixture())
    end
  end
end
