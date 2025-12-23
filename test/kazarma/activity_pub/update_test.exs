# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.UpdateTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "activity handler (Kazarma.ActivityPub.handle_activity/1) for Update activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def update_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "update_object_id",
          "actor" => "http://kazarma/-/bob",
          "type" => "Update",
          "to" => ["http://pleroma.com/pub/actors/alice"],
          "object" => "http://pleroma.com/pub/transactions/object_id"
        },
        object: %{
          data: %{"content" => "hi"}
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

    test "when receiving a Update activity for an existing object, gets the corresponding ids and forwards the replace event" do
      Kazarma.Matrix.TestClient
      |> expect_send_message(
        "@bob:kazarma",
        "!room:kazarma",
        %{
          "body" => "* hi \uFEFF",
          "format" => "org.matrix.custom.html",
          "formatted_body" => "* hi",
          "m.new_content" => %{
            "body" => "hi",
            "format" => "org.matrix.custom.html",
            "formatted_body" => "hi",
            "msgtype" => "m.text"
          },
          "m.relates_to" => %{"event_id" => "local_id", "rel_type" => "m.replace"},
          "msgtype" => "m.text"
        },
        "update_event_id"
      )

      assert :ok == handle_activity(update_fixture())

      assert [
               %MatrixAppService.Bridge.Event{
                 local_id: "local_id",
                 remote_id: "http://pleroma.com/pub/transactions/object_id",
                 room_id: "!room:kazarma"
               },
               %MatrixAppService.Bridge.Event{
                 local_id: "update_event_id",
                 remote_id: "update_object_id",
                 room_id: "!room:kazarma"
               }
             ] = Bridge.list_events()
    end
  end
end
