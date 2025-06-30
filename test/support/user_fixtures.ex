# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.UserFixtures do
  @moduledoc """
  User fixtures
  """

  def create_ap_user_alice() do
    {:ok, alice} =
      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Person",
          "name" => "Alice",
          "preferredUsername" => "alice",
          "url" => "http://pleroma.com/pub/actors/alice",
          "id" => "http://pleroma.com/pub/actors/alice",
          "username" => "alice@pleroma.com"
        },
        "local" => false,
        "public" => true,
        "actor" => "http://pleroma.com/pub/actors/alice"
      })

    alice
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    {:ok, _user} =
      Kazarma.Bridge.create_user(%{
        local_id: "@alice.pleroma.com:kazarma",
        remote_id: "http://pleroma.com/pub/actors/alice"
      })

    alice
  end

  def create_local_matrix_user_bob() do
    {:ok, bob} =
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

    bob
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    {:ok, _user} =
      Kazarma.Bridge.create_user(%{
        local_id: "@bob:kazarma",
        remote_id: "http://kazarma/-/bob"
      })

    bob
  end

  def create_local_matrix_user_carole() do
    {:ok, carole} =
      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Person",
          "name" => "Carole",
          "preferredUsername" => "carole",
          "url" => "http://kazarma/-/carole",
          "id" => "http://kazarma/-/carole",
          "username" => "carole@kazarma"
        },
        "local" => true,
        "public" => true,
        "actor" => "http://kazarma/-/carole"
      })

    carole
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    {:ok, _user} =
      Kazarma.Bridge.create_user(%{
        local_id: "@carole:kazarma",
        remote_id: "http://kazarma/-/carole"
      })

    carole
  end

  def create_remote_matrix_user_david() do
    {:ok, david} =
      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Person",
          "name" => "David",
          "preferredUsername" => "david",
          "url" => "http://kazarma/matrix.org/david",
          "id" => "http://kazarma/matrix.org/david",
          "username" => "david.matrix.org@kazarma"
        },
        "local" => true,
        "public" => true,
        "actor" => "http://kazarma/matrix.org/david"
      })

    david
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    {:ok, _user} =
      Kazarma.Bridge.create_user(%{
        local_id: "@david:matrix.org",
        remote_id: "http://kazarma/matrix.org/david"
      })

    david
  end

  def create_unknown_ap_user_erin() do
    {:ok, erin} =
      ActivityPub.Object.do_insert(%{
        "data" => %{
          "type" => "Person",
          "name" => "Erin",
          "preferredUsername" => "erin",
          "url" => "http://pleroma.com/pub/actors/erin",
          "id" => "http://pleroma.com/pub/actors/erin",
          "username" => "erin@pleroma.com"
        },
        "local" => false,
        "public" => true,
        "actor" => "http://pleroma.com/pub/actors/erin"
      })

    erin
    |> ActivityPub.Actor.format_remote_actor()
    |> ActivityPub.Actor.set_cache()

    erin
  end
end
