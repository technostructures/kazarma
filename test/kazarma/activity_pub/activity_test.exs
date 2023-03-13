# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
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
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
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

  describe "Content conversion" do
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
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:send_message, fn
        "!room:kazarma",
        {"@bob:kazarma hello \uFEFF",
         ~s(<p><a href="https://matrix.to/#/@bob:kazarma">Bob</a> hello</p>)},
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

      assert :ok = handle_activity(public_note_fixture_with_mention())
    end
  end
end
