# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.BlockTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "activity handler (Kazarma.ActivityPub.handle_activity/1) for Block activity" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def block_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "block_object_id",
          "type" => "Block",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "object" => "http://kazarma/-/bob"
        }
      }
    end

    def unblock_fixture do
      %ActivityPub.Object{
        data: %{
          "id" => "unblock_object_id",
          "type" => "Undo",
          "actor" => "http://pleroma.com/pub/actors/alice",
          "object" => %{
            "type" => "Block",
            "object" => "http://kazarma/-/bob"
          }
        }
      }
    end

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          local_id: "local_id",
          remote_id: "http://pleroma.com/pub/actors/alice",
          data: %{
            "type" => "ap_user",
            "matrix_id" => "@alice.pleroma.com:kazarma"
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
          "local" => true,
          "public" => true,
          "actor" => "http://kazarma/-/bob"
        })

      alice = create_ap_user_alice()

      {:ok, actor: alice}
    end

    test "when receiving a Block activity for a Matrix user it ignores the user and bans them from the actor room" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_get_data("@alice.pleroma.com:kazarma", "m.ignored_user_list", %{})
      |> expect_put_data("@alice.pleroma.com:kazarma", "m.ignored_user_list", %{
        "@bob:kazarma" => %{}
      })
      |> expect_send_state_event(
        "@alice.pleroma.com:kazarma",
        "local_id",
        "m.room.member",
        "@bob:kazarma",
        %{"membership" => "ban"},
        :ok
      )

      assert :ok == handle_activity(block_fixture())
    end

    test "when receiving a Undo/Block activity for a Matrix user it unignores the user and unbans them from the actor room" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile("@bob:kazarma", %{"displayname" => "Bob"})
      |> expect_get_data("@alice.pleroma.com:kazarma", "m.ignored_user_list", %{
        "@bob:kazarma" => %{}
      })
      |> expect_put_data("@alice.pleroma.com:kazarma", "m.ignored_user_list", %{})
      |> expect_send_state_event(
        "@alice.pleroma.com:kazarma",
        "local_id",
        "m.room.member",
        "@bob:kazarma",
        %{"membership" => "leave"},
        :ok
      )

      assert :ok == handle_activity(unblock_fixture())
    end
  end
end
