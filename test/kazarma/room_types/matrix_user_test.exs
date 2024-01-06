# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.RoomTypes.MatrixUserTest do
  @moduledoc """
  """
  use Kazarma.DataCase

  import Kazarma.Matrix.Transaction
  alias MatrixAppService.Event
  alias Kazarma.Bridge

  describe "When declaring a new Matrix user room" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    def set_outbox_event_fixture do
      %Event{
        sender: "@bob:kazarma",
        room_id: "!foo:kazarma",
        user_id: "@bob:kazarma",
        type: "m.room.message",
        content: %{"msgtype" => "m.text", "body" => "!kazarma outbox"}
      }
    end

    test "it saves the room as a matrix user room" do
      Kazarma.Matrix.TestClient
      |> expect(:get_state, fn "!foo:kazarma", "m.room.power_levels", "" ->
        {:ok,
         %{
           "users" => %{
             "@bob:kazarma" => 100
           }
         }}
      end)
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      assert {:ok,
              %MatrixAppService.Bridge.Room{
                data: %{type: :matrix_user, matrix_id: "@bob:kazarma"},
                local_id: "!foo:kazarma",
                remote_id: "http://kazarma/-/bob"
              }} = new_event(set_outbox_event_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 data: %{"matrix_id" => "@bob:kazarma", "type" => "matrix_user"},
                 local_id: "!foo:kazarma",
                 remote_id: "http://kazarma/-/bob"
               }
             ] = Bridge.list_rooms()
    end

    test "it doesn't save the room as a matrix user room if the user is not an administrator in the room" do
      Kazarma.Matrix.TestClient
      |> expect(:get_state, fn "!foo:kazarma", "m.room.power_levels", "" ->
        {:ok,
         %{
           "users" => %{
             "@bob:kazarma" => 50
           }
         }}
      end)

      assert nil == new_event(set_outbox_event_fixture())

      assert [] = Bridge.list_rooms()
    end
  end

  describe "When sending a message to a Matrix user room as the user" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@bob:kazarma", "type" => "matrix_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://kazarma/-/bob"
        })

      :ok
    end

    def status_event_fixture do
      %Event{
        sender: "@bob:kazarma",
        room_id: "!foo:kazarma",
        user_id: "@bob:kazarma",
        type: "m.room.message",
        content: %{"msgtype" => "m.text", "body" => "Hello ActivityPub"}
      }
    end

    test "it forwards the message from the user on ActivityPub" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, fn "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/bob",
              "name" => "Bob",
              "preferredUsername" => "bob",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/bob",
            username: "bob@kazarma"
          },
          object: %{
            "actor" => "http://kazarma/-/bob",
            "attributedTo" => "http://kazarma/-/bob",
            "content" => "Hello ActivityPub",
            "tag" => [],
            "to" => ["https://www.w3.org/ns/activitystreams#Public"],
            "type" => "Note"
          },
          to: ["https://www.w3.org/ns/activitystreams#Public"]
        } ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "http://kazarma/-/bob/Note/1"}}}}
      end)

      assert :ok == new_event(status_event_fixture())
    end
  end

  describe "When sending a message to a Matrix user room as another user" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      {:ok, _room} =
        Bridge.create_room(%{
          data: %{"matrix_id" => "@bob:kazarma", "type" => "matrix_user"},
          local_id: "!foo:kazarma",
          remote_id: "http://kazarma/-/bob"
        })

      :ok
    end

    def status_mention_event_fixture do
      %Event{
        sender: "@alice:kazarma",
        room_id: "!foo:kazarma",
        user_id: "@alice:kazarma",
        type: "m.room.message",
        content: %{"msgtype" => "m.text", "body" => "Hello you"}
      }
    end

    test "it forwards the message on ActivityPub with a mention to the relevant user" do
      Kazarma.Matrix.TestClient
      |> expect(:get_profile, 2, fn
        "@alice:kazarma" ->
          {:ok, %{"displayname" => "Alice"}}

        "@bob:kazarma" ->
          {:ok, %{"displayname" => "Bob"}}
      end)

      Kazarma.ActivityPub.TestServer
      |> expect(:create, fn
        %{
          actor: %ActivityPub.Actor{
            data: %{
              "id" => "http://kazarma/-/alice",
              "name" => "Alice",
              "preferredUsername" => "alice",
              "type" => "Person"
            },
            local: true,
            ap_id: "http://kazarma/-/alice",
            username: "alice@kazarma"
          },
          object: %{
            "actor" => "http://kazarma/-/alice",
            "attributedTo" => "http://kazarma/-/alice",
            "content" =>
              "<span class=\"h-card\"><a href=\"http://kazarma/-/bob\" class=\"u-url mention\">@<span>bob@kazarma</span></a></span>Hello you",
            "tag" => [%{"href" => "http://kazarma/-/bob", "name" => "@bob", "type" => "Mention"}],
            "to" => ["https://www.w3.org/ns/activitystreams#Public", "http://kazarma/-/bob"],
            "type" => "Note"
          },
          to: ["https://www.w3.org/ns/activitystreams#Public", "http://kazarma/-/bob"]
        } ->
          {:ok, %{object: %ActivityPub.Object{data: %{"id" => "http://kazarma/-/bob/Note/2"}}}}
      end)

      assert :ok == new_event(status_mention_event_fixture())
    end
  end
end
