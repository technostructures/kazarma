# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Kazarma.ActivityPub.ActorTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter

  describe "ActivityPub request for a local user (get_actor_by_username/1)" do
    setup :verify_on_exit!

    test "when asked for an existing matrix users returns the corresponding actor and persists it in database" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> %{base_url: "http://matrix"} end)
      |> expect(:get_profile, fn "@alice:kazarma" ->
        {:ok, %{"displayname" => "Alice", "avatar_url" => "mxc://server/image_id"}}
      end)

      assert {:ok, %{keys: keys} = actor} = get_actor_by_username("alice")

      assert %ActivityPub.Actor{
               local: true,
               deactivated: false,
               username: "alice@kazarma",
               ap_id: "http://kazarma/-/alice",
               data: %{
                 "preferredUsername" => "alice",
                 "id" => "http://kazarma/-/alice",
                 "type" => "Person",
                 "name" => "Alice",
                 "icon" => %{
                   "type" => "Image",
                   "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                 },
                 "followers" => "http://kazarma/-/alice/followers",
                 "following" => "http://kazarma/-/alice/following",
                 "inbox" => "http://kazarma/-/alice/inbox",
                 "outbox" => "http://kazarma/-/alice/outbox",
                 "manuallyApprovesFollowers" => false,
                 endpoints: %{
                   "sharedInbox" => "http://kazarma/shared_inbox"
                 }
               }
             } = actor

      assert %{
               data: %{
                 "ap_data" => %{
                   "preferredUsername" => "alice",
                   "id" => "http://kazarma/-/alice",
                   "type" => "Person",
                   "name" => "Alice",
                   "icon" => %{
                     "type" => "Image",
                     "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                   }
                 },
                 "keys" => ^keys
               }
             } = Bridge.get_user_by_local_id("@alice:kazarma")

      assert {:ok,
              %{
                data: %{
                  "preferredUsername" => "alice",
                  "id" => "http://kazarma/-/alice",
                  "type" => "Person",
                  "name" => "Alice",
                  "icon" => %{
                    "type" => "Image",
                    "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                  }
                },
                keys: ^keys
              }} = get_actor_by_username("alice")
    end

    test "when asked for a nonexisting matrix users returns an error tuple" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@nonexisting:kazarma" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = get_actor_by_username("nonexisting")
    end
  end

  describe "Maybe register Matrix puppet user (maybe_create_remote_actor/1)" do
    setup :verify_on_exit!

    test "it registers a puppet user" do
      Kazarma.Matrix.TestClient
      |> expect(:register, fn [
                                username: "_ap_bob___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "@_ap_bob___pleroma:kazarma"}}
      end)
      |> expect(:put_displayname, fn "@_ap_bob___pleroma:kazarma",
                                     "Bob",
                                     user_id: "@_ap_bob___pleroma:kazarma" ->
        :ok
      end)
      |> expect(:upload, fn _blob, _opts, user_id: "@_ap_bob___pleroma:kazarma" ->
        {:ok, "mxc://server/media_id"}
      end)
      |> expect(:put_avatar_url, fn "@_ap_bob___pleroma:kazarma",
                                    "mxc://server/media_id",
                                    user_id: "@_ap_bob___pleroma:kazarma" ->
        :ok
      end)

      assert {:ok, _} =
               maybe_create_remote_actor(%ActivityPub.Actor{
                 username: "bob@pleroma",
                 ap_id: "http://pleroma/users/bob",
                 data: %{
                   "id" => "http://pleroma/users/bob",
                   "name" => "Bob",
                   "icon" => %{"type" => "Image", "url" => "https://via.placeholder.com/150"}
                 }
               })
    end
  end

  describe "Update Matrix puppet user (update_remote_actor/1)" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    test "it update the puppet profile" do
      Kazarma.Matrix.TestClient
      |> expect(:put_displayname, fn
        "@alice:kazarma", "new_name", user_id: "@alice:kazarma" -> :ok
      end)
      |> expect(:upload, fn _blob, _opts, user_id: "@alice:kazarma" ->
        {:ok, "mxc://server/media_id"}
      end)
      |> expect(:put_avatar_url, fn "@alice:kazarma",
                                    "mxc://server/media_id",
                                    user_id: "@alice:kazarma" ->
        :ok
      end)

      {:ok, _user} =
        Bridge.create_user(%{
          local_id: "@alice:kazarma",
          remote_id: "http://kazarma/-/alice"
        })

      assert :ok =
               update_remote_actor(%Ecto.Changeset{
                 changes: %{
                   data: %{
                     "name" => "new_name",
                     "icon" => %{"url" => "https://via.placeholder.com/150"}
                   }
                 },
                 data: %{
                   data: %{
                     "name" => "old_name",
                     "icon" => %{"url" => "https://via.placeholder.com/300"},
                     "id" => "http://kazarma/-/alice"
                   }
                 }
               })
    end
  end
end
