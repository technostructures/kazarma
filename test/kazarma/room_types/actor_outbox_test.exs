# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomTypes.ActorOutboxTest do
  @moduledoc """
  Transaction tests for events received from the Matrix server.
  We use existing Pleroma and Matrix accounts so we can create corresponding
  puppets.
  """
  use Kazarma.DataCase

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
            "content" => "hello",
            "context" => _,
            "conversation" => _,
            "tag" => [
              %{
                "href" => "https://pleroma.interhacker.space/users/test_user_bob2",
                "name" => "@test_user_bob2",
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
end
