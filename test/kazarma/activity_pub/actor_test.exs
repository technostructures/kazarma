defmodule Kazarma.ActivityPub.ActorTest do
  use Kazarma.DataCase

  import Mox
  import Kazarma.ActivityPub.Adapter

  describe "ActivityPub request for a local user (get_actor_by_username/1)" do
    setup :verify_on_exit!

    test "when asked for an existing matrix users returns the corresponding actor and persists it in database" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 2, fn -> %{base_url: "http://matrix"} end)
      |> expect(:get_profile, fn _, "@alice:kazarma" ->
        {:ok, %{"displayname" => "Alice", "avatar_url" => "mxc://server/image_id"}}
      end)

      assert {:ok, %{keys: keys} = actor} = get_actor_by_username("alice")

      assert %ActivityPub.Actor{
               local: true,
               deactivated: false,
               username: "alice@kazarma",
               ap_id: "http://kazarma/pub/actors/alice",
               data: %{
                 "preferredUsername" => "alice",
                 "id" => "http://kazarma/pub/actors/alice",
                 "type" => "Person",
                 "name" => "Alice",
                 "icon" => %{
                   "type" => "Image",
                   "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                 },
                 "followers" => "http://kazarma/pub/actors/alice/followers",
                 "followings" => "http://kazarma/pub/actors/alice/following",
                 "inbox" => "http://kazarma/pub/actors/alice/inbox",
                 "outbox" => "http://kazarma/pub/actors/alice/outbox",
                 "manuallyApprovesFollowers" => false,
                 endpoints: %{
                   "sharedInbox" => "http://kazarma/pub/shared_inbox"
                 }
               }
             } = actor

      assert %{
               data: %{
                 "ap_data" => %{
                   "preferredUsername" => "alice",
                   "id" => "http://kazarma/pub/actors/alice",
                   "type" => "Person",
                   "name" => "Alice",
                   "icon" => %{
                     "type" => "Image",
                     "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                   }
                 },
                 "keys" => ^keys
               }
             } = Kazarma.Matrix.Bridge.get_user_by_local_id("@alice:kazarma")

      assert {:ok,
              %{
                data: %{
                  "preferredUsername" => "alice",
                  "id" => "http://kazarma/pub/actors/alice",
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
      |> expect(:client, fn -> nil end)
      |> expect(:get_profile, fn _, "@nonexisting:kazarma" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = get_actor_by_username("nonexisting")
    end
  end

  describe "Maybe register Matrix puppet user (maybe_create_remote_actor/1)" do
    setup :verify_on_exit!

    test "it registers a puppet user" do
      Kazarma.Matrix.TestClient
      |> expect(:client, 3, fn
        [user_id: "@ap_bob=pleroma:kazarma"] -> :client_bob
      end)
      |> expect(:register, fn [
                                username: "ap_bob=pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma"
                              ] ->
        {:ok, %{"user_id" => "@ap_bob=pleroma:kazarma"}}
      end)
      |> expect(:put_displayname, fn :client_bob, "@ap_bob=pleroma:kazarma", "Bob" ->
        :ok
      end)
      |> expect(:upload, fn :client_bob, _blob, _opts -> {:ok, "mxc://server/media_id"} end)
      |> expect(:put_avatar_url, fn :client_bob,
                                    "@ap_bob=pleroma:kazarma",
                                    "mxc://server/media_id" ->
        :ok
      end)

      assert :ok =
               maybe_create_remote_actor(%ActivityPub.Actor{
                 username: "bob@pleroma",
                 data: %{
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
      |> expect(:client, 3, fn
        [user_id: "@alice:kazarma"] -> :client_alice
      end)
      |> expect(:put_displayname, fn
        :client_alice, "@alice:kazarma", "new_name" -> :ok
      end)
      |> expect(:upload, fn :client_alice, _blob, _opts -> {:ok, "mxc://server/media_id"} end)
      |> expect(:put_avatar_url, fn :client_alice, "@alice:kazarma", "mxc://server/media_id" ->
        :ok
      end)

      {:ok, _user} =
        Kazarma.Matrix.Bridge.create_user(%{
          local_id: "@alice:kazarma",
          remote_id: "http://kazarma/pub/actors/alice"
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
                     "id" => "http://kazarma/pub/actors/alice"
                   }
                 }
               })
    end
  end
end
