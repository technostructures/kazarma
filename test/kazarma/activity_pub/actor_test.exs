defmodule Kazarma.ActivityPub.ActorTest do
  use Kazarma.DataCase

  import Mox
  import Kazarma.ActivityPub.Adapter

  describe "ActivityPub request for a local user (get_actor_by_username/1)" do
    setup :verify_on_exit!

    test "when asked for an existing matrix users returns the corresponding actor" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn -> nil end)
      |> expect(:get_profile, fn _, "@alice:kazarma" ->
        {:ok, %{"displayname" => "Alice"}}
      end)

      assert {:ok, actor} = get_actor_by_username("alice")

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
      |> expect(:client, fn
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

      assert :ok =
               maybe_create_remote_actor(%ActivityPub.Actor{
                 username: "bob@pleroma",
                 data: %{"name" => "Bob"}
               })
    end
  end
end
