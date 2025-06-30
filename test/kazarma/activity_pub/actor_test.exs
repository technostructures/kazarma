# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Kazarma.ActivityPub.ActorTest do
  use Kazarma.DataCase, async: false

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "ActivityPub request for a local Matrix user (get_actor_by_username/1) when private bridge" do
    setup :verify_on_exit!

    test "when asked for an existing local matrix user returns the corresponding actor and persists it in database" do
      Kazarma.Matrix.TestClient
      |> expect_client()
      |> expect_get_profile("@alice:kazarma", %{
        "displayname" => "Alice",
        "avatar_url" => "mxc://server/image_id"
      })

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

    test "when asked for a nonexisting local matrix user returns an error tuple" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile_not_found("@nonexisting:kazarma")

      assert nil == get_actor_by_username("nonexisting")
    end
  end

  describe "ActivityPub request for a remote Matrix user (get_actor_by_username/1) when public bridge" do
    setup :verify_on_exit!
    setup :config_public_bridge

    test "when asked for an existing remote matrix users it returns the corresponding actor and persists it in database" do
      Kazarma.Matrix.TestClient
      |> expect_client()
      |> expect_get_profile("@alice:remote.com", %{
        "displayname" => "Alice",
        "avatar_url" => "mxc://server/image_id"
      })

      assert {:ok, %{keys: keys} = actor} = get_actor_by_username("alice.remote.com")

      assert %ActivityPub.Actor{
               local: true,
               deactivated: false,
               username: "alice.remote.com@kazarma",
               ap_id: "http://kazarma/remote.com/alice",
               data: %{
                 "preferredUsername" => "alice.remote.com",
                 "id" => "http://kazarma/remote.com/alice",
                 "type" => "Person",
                 "name" => "Alice",
                 "icon" => %{
                   "type" => "Image",
                   "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                 },
                 "followers" => "http://kazarma/remote.com/alice/followers",
                 "following" => "http://kazarma/remote.com/alice/following",
                 "inbox" => "http://kazarma/remote.com/alice/inbox",
                 "outbox" => "http://kazarma/remote.com/alice/outbox",
                 "manuallyApprovesFollowers" => false,
                 endpoints: %{
                   "sharedInbox" => "http://kazarma/shared_inbox"
                 }
               }
             } = actor

      assert %{
               data: %{
                 "ap_data" => %{
                   "preferredUsername" => "alice.remote.com",
                   "id" => "http://kazarma/remote.com/alice",
                   "type" => "Person",
                   "name" => "Alice",
                   "icon" => %{
                     "type" => "Image",
                     "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                   }
                 },
                 "keys" => ^keys
               }
             } = Bridge.get_user_by_local_id("@alice:remote.com")

      assert {:ok,
              %{
                data: %{
                  "preferredUsername" => "alice.remote.com",
                  "id" => "http://kazarma/remote.com/alice",
                  "type" => "Person",
                  "name" => "Alice",
                  "icon" => %{
                    "type" => "Image",
                    "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                  }
                },
                keys: ^keys
              }} = get_actor_by_username("alice.remote.com")
    end

    test "when asked for a nonexisting remote matrix user returns an error tuple" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile_not_found("@nonexisting:remote.com")

      assert nil == get_actor_by_username("nonexisting.remote.com")
    end
  end

  describe "Maybe register Matrix puppet user (maybe_create_remote_actor/1)" do
    setup :verify_on_exit!

    test "it registers a puppet user" do
      Kazarma.Matrix.TestClient
      |> expect_register(%{
        username: "bob.pleroma.com",
        matrix_id: "@bob.pleroma.com:kazarma",
        displayname: "Bob"
      })
      |> expect_upload_something("@bob.pleroma.com:kazarma", "mxc://server/media_id")
      |> expect_put_avatar_url("@bob.pleroma.com:kazarma", "mxc://server/media_id")

      assert {:ok, _} =
               maybe_create_remote_actor(%ActivityPub.Actor{
                 username: "bob@pleroma.com",
                 ap_id: "http://pleroma.com/users/bob",
                 data: %{
                   "id" => "http://pleroma.com/users/bob",
                   "name" => "Bob",
                   "icon" => %{
                     "type" => "Image",
                     "url" =>
                       "https://technostructures.org/app/themes/technostructures/resources/favicon.png"
                   }
                 }
               })
    end
  end

  describe "Update Matrix puppet user (update_remote_actor/1)" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "it updates the puppet profile" do
      Kazarma.Matrix.TestClient
      |> expect_put_displayname("@alice:kazarma", "new_name")
      |> expect_upload_something("@alice:kazarma", "mxc://server/media_id")
      |> expect_put_avatar_url("@alice:kazarma", "mxc://server/media_id")

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
                     "icon" => %{
                       "url" =>
                         "https://technostructures.org/app/themes/technostructures/resources/favicon.png"
                     }
                   }
                 },
                 data: %{
                   data: %{
                     "name" => "old_name",
                     "icon" => %{
                       "url" =>
                         "https://technostructures.org/app/themes/technostructures/resources/logo.svg"
                     },
                     "id" => "http://kazarma/-/alice"
                   }
                 }
               })
    end
  end

  describe "ActivityPub request for the application Actor" do
    setup :verify_on_exit!

    test "when asked for an existing matrix users returns the corresponding actor and persists it in database" do
      assert {:ok,
              %ActivityPub.Actor{
                data: %{
                  :endpoints => %{"sharedInbox" => "http://kazarma/shared_inbox"},
                  "id" => "http://kazarma/",
                  "inbox" => "http://kazarma/shared_inbox",
                  "name" => "Kazarma",
                  "outbox" => "http://kazarma/-/kazarma/outbox",
                  "preferredUsername" => "kazarma",
                  "type" => "Application"
                },
                local: true,
                ap_id: "http://kazarma/",
                username: "kazarma@kazarma",
                deactivated: false
              }} = Kazarma.ActivityPub.Actor.get_local_actor("kazarma@kazarma")
    end
  end
end
