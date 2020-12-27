defmodule Kazarma.ActivityPub.AdapterTest do
  use KazarmaWeb.ConnCase, async: true

  import Mox
  import Kazarma.ActivityPub.Adapter

  describe "ActivityPub request for a local user (get_actor_by_username/1)" do
    setup :verify_on_exit!

    test "when asked for an existing matrix users returns the corresponding actor" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn () -> nil end)
      |> expect(:get_profile, fn _, "@alice:kazarma" ->
        {:ok, %{"displayname" => "Alice"}}
      end)

      assert {:ok, actor} = get_actor_by_username("alice")
      assert %ActivityPub.Actor{} = actor
      # TODO: test more
    end

    test "when asked for a nonexisting matrix users returns an error tuple" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn () -> nil end)
      |> expect(:get_profile, fn _, "@nonexisting:kazarma" ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = get_actor_by_username("nonexisting")
    end
  end

  describe "activity handler (handle_activity/1)" do
    def chat_message_fixture do
    end

    test "when receiving a ChatMessage activity for a first conversation creates a new room" do
    end
  end
end
