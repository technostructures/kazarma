# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule ActivityPub.Web.ActivityPubControllerTest do
  use KazarmaWeb.ConnCase, async: true

  setup do
    {:ok, alice} =
      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Person",
          "name" => "Alice",
          "preferredUsername" => "alice",
          "url" => "http://kazarma/-/alice",
          "id" => "http://kazarma/-/alice",
          "username" => "alice@kazarma"
        },
        "local" => true,
        "public" => true,
        "actor" => "http://kazarma/-/alice"
      })

    alice
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    {:ok, bob} =
      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Person",
          "name" => "Bob",
          "preferredUsername" => "bob",
          "url" => "http://pleroma/pub/actors/bob",
          "id" => "http://pleroma/pub/actors/bob",
          "username" => "bob@pleroma"
        },
        "local" => false,
        "public" => true,
        "actor" => "http://pleroma/pub/actors/bob"
      })

    bob
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    ActivityPub.follow(%{actor: alice, object: bob})
    ActivityPub.follow(%{actor: bob, object: alice})

    :ok
  end

  test "/followers for a local actor returns list of followers", %{conn: conn} do
    conn = get(conn, "/-/alice/followers")

    body = json_response(conn, 200)
    assert "http://pleroma/pub/actors/bob" in body["first"]["orderedItems"]
  end

  test "/following for a local actor returns list of followings", %{conn: conn} do
    conn = get(conn, "/-/alice/following")

    body = json_response(conn, 200)
    assert "http://pleroma/pub/actors/bob" in body["first"]["orderedItems"]
  end
end
