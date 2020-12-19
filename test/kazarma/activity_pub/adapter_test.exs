defmodule Kazarma.ActivityPub.AdapterTest do
  use KazarmaWeb.ConnCase, async: true

  import Kazarma.ActivityPub.Adapter

  describe "ActivityPub request for a local user" do
    test "asked for an existing user" do
      actor = get_actor_by_username("existing")

      assert {:ok, %ActivityPub.Actor{}} = actor
    end

    test "asked for an inexisting user" do
      actor = get_actor_by_username("nonexisting")

      assert {:error, :not_found} = actor
    end
  end
end
