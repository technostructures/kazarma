# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Adapter do
  @moduledoc """
  Implementation of `ActivityPub.Adapter`.
  """
  use Kazarma.Config
  @behaviour ActivityPub.Federator.Adapter

  alias Kazarma.Address
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias ActivityPub.Actor
  alias ActivityPub.Object
  alias KazarmaWeb.Endpoint
  alias KazarmaWeb.Router.Helpers, as: Routes

  require Logger

  @impl true
  def actor_url(actor) do
    Routes.activity_pub_url(Endpoint, :actor, server_for_url(actor), Address.localpart(actor))
  end

  def actor_path(actor) do
    Routes.activity_pub_path(Endpoint, :actor, server_for_url(actor), Address.localpart(actor))
  end

  defp server_for_url(%Actor{local: true}), do: "-"
  defp server_for_url(%Actor{local: false} = actor), do: Address.server(actor)

  def federate_actor?(_, _, _), do: true

  @impl true
  def context_url(uuid, actor) do
    Routes.activity_pub_url(
      Endpoint,
      :object,
      server_for_url(actor),
      Address.localpart(actor),
      "context",
      uuid
    )
  end

  @impl true
  def object_url(%{id: uuid, data: %{"type" => type}}, actor) do
    Routes.activity_pub_url(
      Endpoint,
      :object,
      server_for_url(actor),
      Address.localpart(actor),
      String.downcase(type),
      uuid
    )
  end

  def object_path(%{id: uuid, data: %{"type" => type}}, actor) do
    Routes.activity_pub_path(
      Endpoint,
      :object,
      server_for_url(actor),
      Address.localpart(actor),
      String.downcase(type),
      uuid
    )
  end

  @impl true
  def get_actor_by_username(username) do
    Logger.debug("asked for local Matrix user #{username}")

    Kazarma.ActivityPub.Actor.get_local_actor(username)
  end

  @impl true
  def update_local_actor(%Actor{} = actor, data) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_local_actor/2")
    Logger.error("this should no longer happen")
    Logger.debug(inspect(actor))
    Logger.debug(inspect(data))

    {:ok, actor}
  end

  @impl true
  def maybe_create_remote_actor(
        %Actor{
          username: username,
          ap_id: ap_id,
          data: data
        } = actor
      ) do
    Logger.debug("Kazarma.ActivityPub.Adapter.maybe_create_remote_actor/1")
    # Logger.debug(inspect(actor))

    with {:ok, matrix_id} <-
           Kazarma.Address.ap_username_to_matrix_id(username, [:activity_pub]),
         {:ok, %{"user_id" => ^matrix_id}} <-
           Kazarma.Matrix.Client.register(matrix_id) do
      name = Map.get(data, "name") || Map.get(data, "preferredUsername")
      Kazarma.Matrix.Client.put_displayname(matrix_id, name)
      avatar_url = get_in(data, ["icon", "url"])
      if avatar_url, do: Kazarma.Matrix.Client.upload_and_set_avatar(matrix_id, avatar_url)

      {:ok, user} =
        Bridge.create_user(%{
          local_id: matrix_id,
          remote_id: ap_id,
          data: %{}
        })

      Kazarma.Logger.log_created_puppet(user,
        type: :matrix
      )

      Kazarma.RoomType.ApUser.create_outbox_if_public_group(actor)

      {:ok, actor}
    else
      {:error, _code, %{"error" => error}} ->
        Logger.error(error)
        {:ok, actor}

      {:error, error} ->
        Logger.error(error)
        {:ok, actor}

      {:ok, _} ->
        {:ok, actor}

      :ok ->
        {:ok, actor}

      other ->
        Logger.debug(inspect(other))
        {:ok, actor}
    end
  end

  @impl true
  def update_remote_actor(
        %Ecto.Changeset{changes: %{data: changes}, data: %{data: previous}} = changeset
      ) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_remote_actor/1")
    Logger.debug(inspect(changeset))

    with %{local_id: matrix_id} <- Bridge.get_user_by_remote_id(previous["id"]) do
      set_if_changed(previous["name"], changes["name"], fn name ->
        Kazarma.Matrix.Client.put_displayname(matrix_id, name)
      end)

      set_if_changed(previous["icon"]["url"], changes["icon"]["url"], fn avatar_url ->
        Kazarma.Matrix.Client.upload_and_set_avatar(matrix_id, avatar_url)
      end)
    end

    :ok
  end

  def update_remote_actor(_), do: :ok

  # @TODO: dispatch depending of existing Room record
  @impl true
  def handle_activity(
        %{
          data: %{"type" => "Create", "to" => to}
        } = activity
      ) do
    result =
      if "https://www.w3.org/ns/activitystreams#Public" in to do
        Kazarma.RoomType.ApUser.create_from_ap(activity)
      else
        case activity do
          %{
            object: %Object{
              data: %{
                "type" => "ChatMessage"
              }
            }
          } ->
            Kazarma.Logger.log_received_activity(activity, label: "Chat")
            Kazarma.RoomType.Chat.create_from_ap(activity)

          %{
            data: %{"to" => _},
            object: %Object{
              data: %{
                "id" => _,
                "actor" => _,
                "conversation" => _
              }
            }
          } ->
            Kazarma.Logger.log_received_activity(activity, label: "Direct message")
            Kazarma.RoomType.DirectMessage.create_from_ap(activity)

          %{
            data: %{"actor" => _},
            object: %Object{
              data: %{
                "id" => _,
                "attributedTo" => _,
                "to" => [_]
              }
            }
          } ->
            Kazarma.Logger.log_received_activity(activity, label: "To collection")
            Kazarma.RoomType.Collection.create_from_ap(activity)
        end
      end

    case result do
      {:error, error} ->
        Logger.error(error)

      {:ok, _} ->
        :ok

      :ok ->
        :ok

      other ->
        Logger.debug(inspect(other))
        :ok
    end
  end

  # Delete activity
  def handle_activity(
        %Object{
          data: %{
            "id" => delete_remote_id,
            "actor" => sender_ap_id,
            "type" => "Delete",
            # "to" => [to_id],
            "object" => object_ap_id
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity)

    {:ok, sender_matrix_id} = Address.ap_id_to_matrix(sender_ap_id)

    for %BridgeEvent{local_id: event_id, room_id: room_id} <-
          Bridge.get_events_by_remote_id(object_ap_id) do
      {:ok, delete_event_id} =
        Kazarma.Matrix.Client.redact_message(
          sender_matrix_id,
          room_id,
          event_id
        )

      Bridge.create_event(%{
        local_id: delete_event_id,
        remote_id: delete_remote_id,
        room_id: room_id
      })
    end

    :ok
  end

  # @TODO check if user can invite (same origin)
  def handle_activity(
        %{
          data: %{
            "type" => "Invite",
            "id" => invite_id,
            "object" => group_ap_id,
            "actor" => _inviter,
            "target" => invitee
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity)

    with {:ok, invitee_matrix_id} <- Address.ap_id_to_matrix(invitee),
         {:ok,
          %{
            username: group_username,
            data: %{"name" => group_name, "endpoints" => %{"members" => _group_members}}
          }} <- ActivityPub.Actor.get_cached(ap_id: group_ap_id),
         {:ok, group_matrix_id} <-
           Address.ap_username_to_matrix_id(group_username),
         {:ok, room_id} <-
           Kazarma.RoomType.Collection.get_or_create_collection_room(
             group_ap_id,
             group_matrix_id,
             group_name
           ),
         {:ok, event_id} <-
           Kazarma.Matrix.Client.invite(room_id, group_matrix_id, invitee_matrix_id) do
      Bridge.create_event(%{
        local_id: event_id,
        remote_id: invite_id,
        room_id: room_id
      })

      :ok
    end
  end

  # Kick (Remove/Invite)
  def handle_activity(
        %{
          data: %{
            "type" => "Remove",
            "actor" => _remover,
            "object" => %{
              data: %{
                "type" => "Invite",
                "target" => removed,
                "object" => group
              }
            }
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity)

    with {:ok, removed_matrix_id} <- Address.ap_id_to_matrix(removed),
         {:ok, group_matrix_id} <- Address.ap_id_to_matrix(group),
         %MatrixAppService.Bridge.Room{local_id: room_id, data: %{"type" => "collection"}} <-
           Kazarma.Bridge.get_room_by_remote_id(group),
         {:ok, _event_id} <-
           Kazarma.Matrix.Client.kick(room_id, group_matrix_id, removed_matrix_id) do
      :ok
    end
  end

  # Follow
  def handle_activity(
        %{
          data: %{
            "type" => "Follow",
            "actor" => follower,
            "object" => followed
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity, label: "Follow")

    case ActivityPub.Actor.get_cached(ap_id: followed) do
      {:ok, %ActivityPub.Actor{local: true} = followed_actor} ->
        Kazarma.ActivityPub.accept(%{
          to: [follower],
          actor: followed_actor,
          object: activity.data["id"]
        })

        if followed == Address.relay_ap_id() do
          Logger.debug("follow back remote actor")
          {:ok, follower_actor} = ActivityPub.Actor.get_cached(ap_id: follower)
          Kazarma.ActivityPub.follow(%{actor: followed_actor, object: follower_actor})
          {:ok, _} = Kazarma.RoomType.ApUser.create_outbox(follower_actor)
        end

        :ok

      _ ->
        :error
    end
  end

  # Unfollow (Undo/Follow)
  def handle_activity(
        %{
          data: %{
            "type" => "Undo",
            "actor" => follower,
            "object" => %{
              "type" => "Follow",
              "object" => followed
            }
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity, label: "Unfollow")

    case ActivityPub.Actor.get_cached(ap_id: followed) do
      {:ok, %ActivityPub.Actor{local: true} = followed_actor} ->
        if followed == Address.relay_ap_id() do
          Logger.debug("unfollow back remote actor")
          {:ok, follower_actor} = ActivityPub.Actor.get_cached(ap_id: follower)
          Kazarma.ActivityPub.unfollow(%{actor: followed_actor, object: follower_actor})
          Kazarma.RoomType.ApUser.deactivate_outbox(follower_actor)
        end

        :ok

      _ ->
        :error
    end
  end

  # Block
  def handle_activity(
        %{
          data: %{
            "type" => "Block",
            "actor" => blocker,
            "object" => blocked
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity, label: "Block")

    case ActivityPub.Actor.get_cached(ap_id: blocked) do
      {:ok, %ActivityPub.Actor{local: true} = _blocked_actor} ->
        {:ok, blocker_matrix_id} = Address.ap_id_to_matrix(blocker)
        {:ok, blocked_matrix_id} = Address.ap_id_to_matrix(blocked)

        Kazarma.Matrix.Client.ignore(blocker_matrix_id, blocked_matrix_id)

        case Kazarma.RoomType.ApUser.get_outbox(blocker) do
          {:ok, %MatrixAppService.Bridge.Room{local_id: room_id, data: %{"type" => "ap_user"}}} ->
            Kazarma.Matrix.Client.ban(room_id, blocker_matrix_id, blocked_matrix_id)
        end

        :ok

      _ ->
        :error
    end
  end

  # Unblock (Undo/Block)
  def handle_activity(
        %{
          data: %{
            "type" => "Undo",
            "actor" => blocker,
            "object" => %{
              "type" => "Block",
              "object" => blocked
            }
          }
        } = activity
      ) do
    Kazarma.Logger.log_received_activity(activity, label: "Block")

    case ActivityPub.Actor.get_cached(ap_id: blocked) do
      {:ok, %ActivityPub.Actor{local: true} = _blocked_actor} ->
        {:ok, blocker_matrix_id} = Address.ap_id_to_matrix(blocker)
        {:ok, blocked_matrix_id} = Address.ap_id_to_matrix(blocked)

        Kazarma.Matrix.Client.unignore(blocker_matrix_id, blocked_matrix_id)

        case Kazarma.RoomType.ApUser.get_outbox(blocker) do
          {:ok, %MatrixAppService.Bridge.Room{local_id: room_id, data: %{"type" => "ap_user"}}} ->
            Kazarma.Matrix.Client.unban(room_id, blocker_matrix_id, blocked_matrix_id)
        end

        :ok

      _ ->
        :error
    end
  end

  def handle_activity(%Object{} = activity) do
    Kazarma.Logger.log_received_activity(activity, label: "Unhandled activity")

    :ok
    # raise "handle_activity/1: not implemented"
  end

  @impl true
  def get_actor_by_id(id) do
    Logger.error("get_actor_by_id called (#{id})")

    {:error, :not_found}
  end

  @impl true
  def get_follower_local_ids(_actor) do
    []
    # raise "get_follower_local_ids/1: not implemented"
  end

  @impl true
  def get_following_local_ids(_actor) do
    []
    # raise "get_following_local_ids/1: not implemented"
  end

  @impl true
  def base_url, do: KazarmaWeb.Endpoint.url()

  @impl true
  def domain, do: Application.get_env(:activity_pub, :domain)

  @impl true
  def get_redirect_url(_id_or_username) do
    raise "get_redirect_url/1: not implemented"
  end

  @impl true
  def actor_html(conn, _username) do
    # KazarmaWeb.ActorController.show(conn, %{"username" => username})
    conn
  end

  @impl true
  def object_html(conn, _uuid) do
    # KazarmaWeb.ObjectController.show(conn, %{"uuid" => uuid})
    conn
  end

  @impl true
  def external_followers_for_activity(_actor, _activity) do
    {:ok, []}
    # raise "external_followers_for_activity/2: not implemented"
  end

  @impl true
  def get_actor_by_ap_id(ap_id) do
    Logger.warning("get_actor_by_ap_id called (#{ap_id})")
    %URI{host: host, path: path} = URI.parse(ap_id)

    case Phoenix.Router.route_info(KazarmaWeb.Router, "GET", path, host) do
      %{path_params: %{"server" => "-", "localpart" => localpart}} ->
        get_actor_by_username(localpart)

      _ ->
        nil
    end
  end

  @impl true
  def get_locale() do
    "und"
  end

  @impl true
  def get_or_create_service_actor() do
    Kazarma.ActivityPub.Actor.get_relay_actor()
  end

  @impl true
  def maybe_publish_object(_object, _manually_fetching?) do
    raise "maybe_publish_object/2: not implemented"
  end

  defp set_if_changed(previous_value, new_value, _update_fun)
       when previous_value == new_value or is_nil(new_value),
       do: nil

  defp set_if_changed(_previous_value, new_value, update_fun), do: update_fun.(new_value)
end
