# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.DeleteTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "activity handler (Kazarma.ActivityPub.handle_activity/1) for Delete activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def delete_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "delete_object_id",
          "actor" => "http://kazarma/-/bob",
          "type" => "Delete",
          "to" => ["http://pleroma.com/pub/actors/alice"],
          "object" => "http://pleroma.com/pub/transactions/object_id"
        }
      }
    end

    setup do
      create_local_matrix_user_bob()

      {:ok, _event} =
        Bridge.create_event(%{
          local_id: "local_id",
          remote_id: "http://pleroma.com/pub/transactions/object_id",
          room_id: "!room:kazarma"
        })

      :ok
    end

    test "when receiving a Delete activity for an existing object, gets the corresponding ids and forwards the redact event" do
      Kazarma.Matrix.TestClient
      |> expect_redact_message("@bob:kazarma", "!room:kazarma", "local_id", "delete_event_id")

      assert :ok == handle_activity(delete_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "http://pleroma.com/pub/transactions/object_id",
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
end
