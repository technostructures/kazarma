# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.FollowTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "activity handler (Kazarma.ActivityPub.handle_activity/1) for Follow activity to an AP puppet" do
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

  describe "activity handler (Kazarma.ActivityPub.handle_activity/1) for Follow activity to the profile bridging bot" do
    setup :set_mox_from_context
    setup :verify_on_exit!
    setup :config_public_bridge

    setup do
      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
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

      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@profile_bridge:kazarma",
          remote_id: "http://kazarma/-/profile_bridge",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/-/profile_bridge",
              "preferredUsername" => "profile_bridge",
              "name" => "Kazarma",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/avatar"},
              "type" => "Application"
            },
            "keys" => keys
          }
        })

      :ok
    end

    def follow_profile_bridge_fixture do
      %{
        data: %{
          "type" => "Follow",
          "id" => "follow_object_id",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => "http://kazarma/-/profile_bridge"
        }
      }
    end

    test "following the activity bot actor makes it accept, follow back and creates the bridge user" do
      Kazarma.Matrix.TestClient
      |> expect_register(%{
        username: "alice.pleroma",
        matrix_id: "@alice.pleroma:kazarma",
        displayname: "Alice"
      })

      Kazarma.ActivityPub.TestServer
      |> expect(:accept, fn
        %{
          actor: %{
            data: %{
              "id" => "http://kazarma/-/profile_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "profile_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/profile_bridge",
            username: "profile_bridge@kazarma",
            deactivated: false
          },
          object: "follow_object_id",
          to: ["http://pleroma/pub/actors/alice"]
        } ->
          :ok
      end)
      |> expect(:follow, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/profile_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "profile_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/profile_bridge",
            username: "profile_bridge@kazarma"
          },
          object: %ActivityPub.Actor{
            data: %{
              "id" => "http://pleroma/pub/actors/alice",
              "name" => "Alice",
              "preferredUsername" => "alice",
              "type" => "Person",
              "url" => "http://pleroma/pub/actors/alice",
              "username" => "alice@pleroma"
            },
            local: false,
            ap_id: "http://pleroma/pub/actors/alice",
            username: "alice@pleroma"
          }
        } ->
          :ok
      end)

      assert :ok = handle_activity(follow_profile_bridge_fixture())

      assert [
               %{
                 local_id: "@profile_bridge:kazarma",
                 remote_id: "http://kazarma/-/profile_bridge"
               },
               %MatrixAppService.Bridge.User{
                 local_id: "@alice.pleroma:kazarma",
                 remote_id: "http://pleroma/pub/actors/alice"
               }
             ] = Bridge.list_users()
    end
  end

  describe "activity handler (Kazarma.ActivityPub.handle_activity/1) for Undo/Follow activity to the profile bridging bot" do
    setup :set_mox_from_context
    setup :verify_on_exit!
    setup :config_public_bridge

    setup do
      {:ok, _actor} =
        ActivityPub.Object.do_insert(%{
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

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@alice.pleroma:kazarma",
          remote_id: "http://pleroma/pub/actors/alice"
        })

      {:ok, keys} = ActivityPub.Safety.Keys.generate_rsa_pem()

      {:ok, _user} =
        Kazarma.Bridge.create_user(%{
          local_id: "@profile_bridge:kazarma",
          remote_id: "http://kazarma/-/profile_bridge",
          data: %{
            "ap_data" => %{
              "id" => "http://kazarma/-/profile_bridge",
              "preferredUsername" => "profile_bridge",
              "name" => "Kazarma",
              "icon" => %{"url" => "http://matrix/_matrix/media/r0/download/server/avatar"},
              "type" => "Application"
            },
            "keys" => keys
          }
        })

      :ok
    end

    def unfollow_profile_bridge_fixture do
      %{
        data: %{
          "type" => "Undo",
          "actor" => "http://pleroma/pub/actors/alice",
          "object" => %{
            "type" => "Follow",
            "id" => "follow_object_id",
            "object" => "http://kazarma/-/profile_bridge"
          }
        }
      }
    end

    test "unfollowing the activity bot actor makes it unfollow back and removes the bridge user" do
      Kazarma.ActivityPub.TestServer
      |> expect(:unfollow, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/profile_bridge",
              "name" => "Kazarma",
              "preferredUsername" => "profile_bridge",
              "type" => "Application"
            },
            local: true,
            ap_id: "http://kazarma/-/profile_bridge",
            username: "profile_bridge@kazarma"
          },
          object: %ActivityPub.Actor{
            data: %{
              "id" => "http://pleroma/pub/actors/alice",
              "name" => "Alice",
              "preferredUsername" => "alice",
              "type" => "Person",
              "url" => "http://pleroma/pub/actors/alice",
              "username" => "alice@pleroma"
            },
            local: false,
            ap_id: "http://pleroma/pub/actors/alice",
            username: "alice@pleroma"
          }
        } ->
          :ok
      end)

      assert :ok = handle_activity(unfollow_profile_bridge_fixture())

      assert [
               %{
                 local_id: "@profile_bridge:kazarma",
                 remote_id: "http://kazarma/-/profile_bridge"
               }
             ] = Bridge.list_users()
    end
  end
end
