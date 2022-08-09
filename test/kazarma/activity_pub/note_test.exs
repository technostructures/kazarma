# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.NoteTest do
  use Kazarma.DataCase
  require Logger

  import Mox
  import Kazarma.ActivityPub.Adapter

  describe "activity handler (handle_activity/1) for Note" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
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

      {:ok, actor: actor}
    end

    # @TODO: test errors that can happen

    def note_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => ["http://kazarma/pub/actors/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "source" => "hello",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil
          }
        }
      }
    end

    def note_with_attachments_fixture do
      %{
        data: %{
          "type" => "Create",
          "actor" => "http://pleroma/pub/actors/alice",
          "to" => ["http://kazarma/pub/actors/bob"]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "actor" => "http://pleroma/pub/actors/alice",
            "content" => "hello",
            "context" => "http://pleroma.local/contexts/aabbccddeeff",
            "conversation" => "http://pleroma.local/contexts/aabbccddeeff",
            "attachment" => [
              %{
                "mediaType" => "image/jpeg",
                "name" => nil,
                "type" => "Document",
                "url" => "http://example.com/example.jpg"
              },
              %{
                "mediaType" => "image/jpeg",
                "name" => nil,
                "type" => "Document",
                "url" => "http://example.com/example2.jpg"
              }
            ],
            "source" => "hello",
            "summary" => "something"
          }
        }
      }
    end

    test "when receiving a Note activity for an existing conversation gets the corresponding room and forwards the message" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello"},
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, :something}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/contexts/context",
        data: %{
          "type" => "note",
          "to" => ["@_ap_alice___pleroma:kazarma", "@bob:kazarma"]
        }
      }
      |> Kazarma.Matrix.Bridge.create_room()

      assert :ok = handle_activity(note_fixture())
    end

    test "when receiving a Note activity for a first conversation creates a new room and sends forward the message" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:create_room, fn
        [
          visibility: :private,
          name: nil,
          topic: nil,
          is_direct: false,
          invite: ["@bob:kazarma"],
          room_version: "5"
        ],
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, %{"room_id" => "!room:kazarma"}}
      end)
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello"},
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, :something}
      end)

      assert :ok = handle_activity(note_fixture())

      assert [
               %MatrixAppService.Bridge.Room{
                 local_id: "!room:kazarma",
                 remote_id: "http://pleroma/pub/contexts/context",
                 data: %{
                   "type" => "note",
                   "to" => ["@_ap_alice___pleroma:kazarma", "@bob:kazarma"]
                 }
               }
             ] = Kazarma.Matrix.Bridge.list_rooms()
    end

    test "when receiving a Note activity with attachments and some text forwards the attachments and the text" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 2, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "_ap_alice___pleroma:kazarma"] -> :client_alice
        [user_id: "@_ap_alice___pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:create_attachment_message, 2, fn
        :client_alice,
        {:data, _, "example.jpg"},
        [
          body: "example.jpg",
          filename: "example.jpg",
          mimetype: "image/jpeg",
          msgtype: "m.image"
        ] ->
          {:ok,
           %{
             msgtype: "m.image",
             info: %{"filename" => "example.jpeg", "mimetype" => "image/jpeg"}
           }}

        :client_alice,
        {:data, _, "example2.jpg"},
        [
          body: "example2.jpg",
          filename: "example2.jpg",
          mimetype: "image/jpeg",
          msgtype: "m.image"
        ] ->
          {:ok,
           %{
             msgtype: "m.image",
             info: %{"filename" => "example2.jpeg", "mimetype" => "image/jpeg"}
           }}
      end)
      |> expect(:send_message, 3, fn
        "!room:kazarma", {"hello \uFEFF", "hello"}, [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}

        "!room:kazarma",
        %{
          msgtype: "m.image",
          info: %{
            "filename" => "example.jpeg",
            "mimetype" => "image/jpeg"
          }
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}

        "!room:kazarma",
        %{
          msgtype: "m.image",
          info: %{
            "filename" => "example2.jpeg",
            "mimetype" => "image/jpeg"
          }
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma.local/contexts/aabbccddeeff",
        data: %{
          "type" => "note",
          "to" => ["@_ap_alice___pleroma:kazarma", "@bob:kazarma"]
        }
      }
      |> Kazarma.Matrix.Bridge.create_room()

      assert :ok = handle_activity(note_with_attachments_fixture())
    end

    test "when receiving a Note activity with attachments and no text forwards only the attachments" do
      Kazarma.Matrix.TestClient
      |> expect(:client, fn ->
        :client_kazarma
      end)
      |> expect(:client, 2, fn
        [user_id: "@bob:kazarma"] -> :client_bob
        [user_id: "_ap_alice___pleroma:kazarma"] -> :client_alice
        [user_id: "@_ap_alice___pleroma:kazarma"] -> :client_alice
      end)
      |> expect(:register, fn [
                                username: "_ap_alice___pleroma",
                                device_id: "KAZARMA_APP_SERVICE",
                                initial_device_display_name: "Kazarma",
                                registration_type: "m.login.application_service"
                              ] ->
        {:ok, %{"user_id" => "_ap_alice___pleroma:kazarma"}}
      end)
      |> expect(:get_profile, fn :client_kazarma, "@bob:kazarma" ->
        {:ok, %{"displayname" => "Bob"}}
      end)
      |> expect(:create_attachment_message, 2, fn
        :client_alice,
        {:data, _, "example.jpg"},
        [
          body: "example.jpg",
          filename: "example.jpg",
          mimetype: "image/jpeg",
          msgtype: "m.image"
        ] ->
          {:ok,
           %{
             msgtype: "m.image",
             info: %{"filename" => "example.jpeg", "mimetype" => "image/jpeg"}
           }}

        :client_alice,
        {:data, _, "example2.jpg"},
        [
          body: "example2.jpg",
          filename: "example2.jpg",
          mimetype: "image/jpeg",
          msgtype: "m.image"
        ] ->
          {:ok,
           %{
             msgtype: "m.image",
             info: %{"filename" => "example2.jpeg", "mimetype" => "image/jpeg"}
           }}
      end)
      |> expect(:send_message, 2, fn
        "!room:kazarma",
        %{
          msgtype: "m.image",
          info: %{
            "filename" => "example.jpeg",
            "mimetype" => "image/jpeg"
          }
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}

        "!room:kazarma",
        %{
          msgtype: "m.image",
          info: %{
            "filename" => "example2.jpeg",
            "mimetype" => "image/jpeg"
          }
        },
        [user_id: "@_ap_alice___pleroma:kazarma"] ->
          {:ok, :something}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma.local/contexts/aabbccddeeff",
        data: %{
          "type" => "note",
          "to" => ["@_ap_alice___pleroma:kazarma", "@bob:kazarma"]
        }
      }
      |> Kazarma.Matrix.Bridge.create_room()

      note =
        note_with_attachments_fixture()
        |> update_in([Access.key!(:object), Access.key!(:data), "content"], fn _ -> nil end)
        |> update_in([Access.key!(:object), Access.key!(:data), "source"], fn _ -> nil end)

      assert :ok = handle_activity(note)
    end

    def public_note_fixture do
      %{
        data: %{
          "type" => "Create",
          "to" => [
            "http://kazarma/pub/actors/bob",
            "https://www.w3.org/ns/activitystreams#Public"
          ]
        },
        object: %ActivityPub.Object{
          data: %{
            "type" => "Note",
            "source" => "hello",
            "actor" => "http://pleroma/pub/actors/alice",
            "conversation" => "http://pleroma/pub/contexts/context",
            "attachment" => nil
          }
        }
      }
    end

    test "receiving a public note forwards it to the puppet's timeline room" do
      Kazarma.Matrix.TestClient
      |> expect(:send_message, fn "!room:kazarma",
                                  {"hello \uFEFF", "hello"},
                                  [user_id: "@_ap_alice___pleroma:kazarma"] ->
        {:ok, :something}
      end)

      %{
        local_id: "!room:kazarma",
        remote_id: "http://pleroma/pub/actors/alice",
        data: %{
          "type" => "outbox",
          "matrix_id" => "@_ap_alice___pleroma:kazarma"
        }
      }
      |> Kazarma.Matrix.Bridge.create_room()

      assert :ok = handle_activity(public_note_fixture())
    end
  end
end
