# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Kazarma.ActivityPub.ActorTest do
  use Kazarma.DataCase

  alias Kazarma.Bridge
  import Kazarma.ActivityPub.Adapter
  import Kazarma.MatrixMocks

  describe "ActivityPub request for a local user (get_actor_by_username/1)" do
    setup :verify_on_exit!

    test "when asked for an existing matrix users returns the corresponding actor and persists it in database" do
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

    test "when asked for an existing remote matrix users returns the corresponding actor and persists it in database" do
      Kazarma.Matrix.TestClient
      |> expect_client()
      |> expect_get_profile("@alice:remote", %{
        "displayname" => "Alice",
        "avatar_url" => "mxc://server/image_id"
      })

      assert {:ok, %{keys: keys} = actor} = get_actor_by_username("alice___remote")

      assert %ActivityPub.Actor{
               local: true,
               deactivated: false,
               username: "alice___remote@kazarma",
               ap_id: "http://kazarma/-/alice___remote",
               data: %{
                 "preferredUsername" => "alice___remote",
                 "id" => "http://kazarma/-/alice___remote",
                 "type" => "Person",
                 "name" => "Alice",
                 "icon" => %{
                   "type" => "Image",
                   "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                 },
                 "followers" => "http://kazarma/-/alice___remote/followers",
                 "following" => "http://kazarma/-/alice___remote/following",
                 "inbox" => "http://kazarma/-/alice___remote/inbox",
                 "outbox" => "http://kazarma/-/alice___remote/outbox",
                 "manuallyApprovesFollowers" => false,
                 endpoints: %{
                   "sharedInbox" => "http://kazarma/shared_inbox"
                 }
               }
             } = actor

      assert %{
               data: %{
                 "ap_data" => %{
                   "preferredUsername" => "alice___remote",
                   "id" => "http://kazarma/-/alice___remote",
                   "type" => "Person",
                   "name" => "Alice",
                   "icon" => %{
                     "type" => "Image",
                     "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                   }
                 },
                 "keys" => ^keys
               }
             } = Bridge.get_user_by_local_id("@alice:remote")

      assert {:ok,
              %{
                data: %{
                  "preferredUsername" => "alice___remote",
                  "id" => "http://kazarma/-/alice___remote",
                  "type" => "Person",
                  "name" => "Alice",
                  "icon" => %{
                    "type" => "Image",
                    "url" => "http://matrix/_matrix/media/r0/download/server/image_id"
                  }
                },
                keys: ^keys
              }} = get_actor_by_username("alice___remote")
    end

    test "when asked for a nonexisting matrix users returns an error tuple" do
      Kazarma.Matrix.TestClient
      |> expect_get_profile_not_found("@nonexisting:kazarma")

      assert {:error, :not_found} = get_actor_by_username("nonexisting")
    end
  end

  describe "Maybe register Matrix puppet user (maybe_create_remote_actor/1)" do
    setup :verify_on_exit!

    test "it registers a puppet user" do
      Kazarma.Matrix.TestClient
      |> expect_register(%{
        username: "_ap_bob___pleroma",
        matrix_id: "@_ap_bob___pleroma:kazarma",
        displayname: "Bob"
      })
      |> expect_upload_something("@_ap_bob___pleroma:kazarma", "mxc://server/media_id")
      |> expect_put_avatar_url("@_ap_bob___pleroma:kazarma", "mxc://server/media_id")

      assert {:ok, _} =
               maybe_create_remote_actor(%ActivityPub.Actor{
                 username: "bob@pleroma",
                 ap_id: "http://pleroma/users/bob",
                 data: %{
                   "id" => "http://pleroma/users/bob",
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
    setup :set_mox_from_context
    setup :verify_on_exit!

    test "it update the puppet profile" do
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
