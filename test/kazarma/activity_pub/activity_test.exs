# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.ActivityTest do
  use Kazarma.DataCase

  import Mox
  import Kazarma.ActivityPub.Adapter

  describe "activity handler (handle_activity/1) for Delete activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def delete_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "delete_object_id",
          "actor" => "http://kazarma/pub/actors/bob",
          "type" => "Delete",
          "to" => ["http://pleroma/pub/actors/alice"],
          "object" => "http://pleroma/pub/transactions/object_id"
        }
      }
    end

    setup do
      {:ok, event} =
        Kazarma.Matrix.Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "http://pleroma/pub/transactions/object_id",
          room_id: "!room:kazarma"
        })

      :ok
    end

    test "when receiving a Delete activity for an existing object, gets the corresponding ids and forwards the redact event" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 1, fn ->
        :client_kazarma
      end)
      |> expect(:client, fn
        [user_id: "@bob:kazarma"] -> :client_bob
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:redact_message, fn :client_bob, "!room:kazarma", "local_id", nil ->
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
             ] = Kazarma.Matrix.Bridge.list_events()
    end
  end
end
