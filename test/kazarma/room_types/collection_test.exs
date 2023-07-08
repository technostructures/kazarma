# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.CollectionTest do
  @moduledoc false

  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter

  describe "activity handler (handle_activity/1) for Invite activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def invite_fixture do
      %ActivityPub.Object{
        data: %{
          "actor" => "http://mobilizon/@alice",
          "cc" => ["http://mobilizon/@group"],
          "id" => "http://mobilizon/member/member",
          "object" => "http://mobilizon/@group",
          "target" => "http://kazarma/-/bob",
          "to" => ["http://kazarma/-/bob"],
          "type" => "Invite"
        }
      }
    end

    def accept_invite_fixture do
      %MatrixAppService.Event{
        event_id: "event_id",
        type: "m.room.member",
        content: %{"membership" => "join"},
        sender: "@bob:kazarma",
        room_id: "!room:kazarma",
        state_key: "@bob:kazarma",
        unsigned: %{
          "prev_content" => %{"membership" => "invite"},
          "replaces_state" => "!invite_event"
        }
      }
    end

    setup do
      {:ok, actor} =
        ActivityPub.Object.insert(%{
          "data" => %{
            "type" => "Group",
            "name" => "Group",
            "preferredUsername" => "group",
            "url" => "http://mobilizon/@group",
            "id" => "http://mobilizon/@group",
            "username" => "group",
            "endpoints" => %{"members" => "http://mobilizon/@group/members"}
          },
          "local" => false,
          "actor" => "http://mobilizon/@group",
          "username" => "group"
        })

      {:ok, actor: actor}
    end

    test "when receiving a Invite activity for a Matrix user it invites them to the collection room" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:register, fn
        [
          username: "_ap_group___mobilizon",
          device_id: "KAZARMA_APP_SERVICE",
          initial_device_display_name: "Kazarma",
          registration_type: "m.login.application_service"
        ] ->
          {:ok, %{"user_id" => "_ap_group___mobilizon:kazarma"}}
      end)
      |> expect(:create_room, fn
        [
          visibility: :private,
          topic: nil,
          is_direct: false,
          invite: [],
          room_version: "5",
          name: "Group"
        ],
        [user_id: "@_ap_group___mobilizon:kazarma"] ->
          {:ok, %{"room_id" => "!room:kazarma"}}
      end)
      |> expect(:send_state_event, fn
        "!room:kazarma",
        "m.room.member",
        "@bob:kazarma",
        %{"membership" => "invite"},
        [user_id: "@_ap_group___mobilizon:kazarma"] ->
          {:ok, "!invite_event"}
      end)

      assert :ok == handle_activity(invite_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{"type" => "collection"},
                 local_id: "!room:kazarma",
                 remote_id: "http://mobilizon/@group/members"
               }
             ] = Bridge.list_rooms()

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "!invite_event",
                 remote_id: "http://mobilizon/member/member",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end

    test "when the user accepts the invitation it sends an Accept/Invite activity" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/bob"
            },
            local: true,
            ap_id: "http://kazarma/-/bob",
            username: "bob@kazarma"
          },
          object: "http://mobilizon/member/member",
          to: ["http://mobilizon/@group/members"]
        } ->
          :ok
      end)

      %{
        data: %{"type" => "collection"},
        local_id: "!room:kazarma",
        remote_id: "http://mobilizon/@group/members"
      }
      |> Bridge.create_room()

      %{
        local_id: "!invite_event",
        remote_id: "http://mobilizon/member/member",
        room_id: "!room:kazarma"
      }
      |> Bridge.create_event()

      assert :ok == Kazarma.Matrix.Transaction.new_event(accept_invite_fixture())
    end
  end
end
