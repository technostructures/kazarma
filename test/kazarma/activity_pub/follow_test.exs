# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.FollowTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "activity handler (Kazarma.ActivityPub.handle_activity/1) for Follow activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      create_local_matrix_user_bob()

      :ok
    end

    def follow_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "follow_object_id",
          "type" => "Follow",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "object" => "http://kazarma/-/bob"
        }
      }
    end

    def unfollow_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "unfollow_object_id",
          "type" => "Undo",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "object" => %{
            "type" => "Follow",
            "object" => "http://kazarma/-/bob"
          }
        }
      }
    end

    test "when receiving a Follow activity for a Matrix user it accepts the follow" do
      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %{
            data: %{
              "id" => "http://kazarma/-/bob",
              "name" => "Bob",
              "preferredUsername" => "bob",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/bob",
            username: "bob@kazarma",
            deactivated: false
          },
          object: "follow_object_id",
          to: ["http://pleroma.com/pub/actors/alice"]
        } ->
          :ok
      end)

      assert :ok == handle_activity(follow_fixture())
    end

    test "when receiving a Undo/Follow activity for a Matrix user it does nothing" do
      assert :ok == handle_activity(unfollow_fixture())
    end
  end
end
