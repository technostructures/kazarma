# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.SearchControllerTest do
  use KazarmaWeb.ConnCase
  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    # {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()

    {:ok, actor} =
      ActivityPub.Object.insert(%{
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

    actor
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    :ok
  end

  describe "the search controller" do
    test "redirects to an user page if found", %{conn: conn} do
      conn =
        post(conn, "/search", %{"search" => %{"address" => "http://pleroma/pub/actors/alice"}})

      assert html_response(conn, 302) ==
               "<html><body>You are being <a href=\"/pleroma/alice\">redirected</a>.</body></html>"
    end

    test "displays an error in case of not found user", %{conn: conn} do
      conn = post(conn, "/search", %{"search" => %{"address" => "http://pleroma/pub/actors/bob"}})

      assert html_response(conn, 302) ==
               "<html><body>You are being <a href=\"/\">redirected</a>.</body></html>"

      assert {:error, {:redirect, %{to: "/", flash: %{"error" => "User not found"}}}} =
               live(conn)
    end
  end
end
