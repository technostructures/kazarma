# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Adapter do
  @moduledoc """
  Implementation of `ActivityPub.Adapter`.
  """
  alias Kazarma.Logger
  use Kazarma.Config
  @behaviour ActivityPub.Adapter

  alias Kazarma.Address
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias ActivityPub.Actor
  alias ActivityPub.Object
  alias KazarmaWeb.Endpoint
  alias KazarmaWeb.Router.Helpers, as: Routes

  @impl ActivityPub.Adapter
  def actor_url(actor) do
    Routes.activity_pub_url(Endpoint, :actor, server_for_url(actor), Address.localpart(actor))
  end

  def actor_path(actor) do
    Routes.activity_pub_path(Endpoint, :actor, server_for_url(actor), Address.localpart(actor))
  end

  defp server_for_url(%Actor{local: true}), do: "-"
  defp server_for_url(%Actor{local: false} = actor), do: Address.server(actor)

  @impl ActivityPub.Adapter
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

  @impl ActivityPub.Adapter
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

  @impl ActivityPub.Adapter
  def get_actor_by_username(username) do
    Logger.debug("asked for local Matrix user #{username}")

    Kazarma.ActivityPub.Actor.get_local_actor(username)
  end

  @impl ActivityPub.Adapter
  def update_local_actor(%Actor{} = actor, data) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_local_actor/2")
    Logger.error("this should no longer happen")
    Logger.debug(inspect(actor))
    Logger.debug(inspect(data))

    {:ok, actor}
  end

  @impl ActivityPub.Adapter
  def maybe_create_remote_actor(%Actor{
        username: username,
        ap_id: ap_id,
        data: %{"name" => name} = data
      }) do
    Logger.debug("Kazarma.ActivityPub.Adapter.maybe_create_remote_actor/1")
    # Logger.debug(inspect(actor))

    with {:ok, matrix_id} <-
           Kazarma.Address.ap_username_to_matrix_id(username, [:activity_pub]),
         {:ok, %{"user_id" => ^matrix_id}} <-
           Kazarma.Matrix.Client.register(matrix_id) do
      Kazarma.Matrix.Client.put_displayname(matrix_id, name)
      avatar_url = get_in(data, ["icon", "url"])
      if avatar_url, do: Kazarma.Matrix.Client.upload_and_set_avatar(matrix_id, avatar_url)

      {:ok, _bridge_user} =
        Bridge.create_user(%{
          local_id: matrix_id,
          remote_id: ap_id,
          data: %{}
        })

      :ok
    else
      {:error, _code, %{"error" => error}} ->
        Logger.error(error)

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

  @impl ActivityPub.Adapter
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

  @impl ActivityPub.Adapter
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
    Logger.debug("Forwarding to Matrix delete activity")
    Logger.ap_input(activity)
    Logger.ap_input(object_ap_id)

    with {:ok, sender_matrix_id} <- Address.ap_id_to_matrix(sender_ap_id),
         %BridgeEvent{local_id: event_id, room_id: room_id} <-
           Bridge.get_event_by_remote_id(object_ap_id),
         {:ok, delete_event_id} <-
           Kazarma.Matrix.Client.redact_message(
             sender_matrix_id,
             room_id,
             event_id
           ) do
      Bridge.create_event(%{
        local_id: delete_event_id,
        remote_id: delete_remote_id,
        room_id: room_id
      })

      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
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
        } = _activity
      ) do
    with {:ok, invitee_matrix_id} <- Address.ap_id_to_matrix(invitee),
         {:ok,
          %{
            username: group_username,
            data: %{"name" => group_name, "endpoints" => %{"members" => group_members}}
          }} <- ActivityPub.Actor.get_cached_by_ap_id(group_ap_id),
         {:ok, group_matrix_id} <-
           Address.ap_username_to_matrix_id(group_username),
         {:ok, room_id} <-
           Kazarma.RoomType.Collection.get_or_create_collection_room(
             group_members,
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
    Logger.debug("received Follow")

    case ActivityPub.Actor.get_cached_by_ap_id(followed) do
      {:ok, %ActivityPub.Actor{local: true} = followed_actor} ->
        ActivityPub.accept(%{to: [follower], actor: followed_actor, object: activity.data})

        if followed == Address.relay_ap_id() do
          Logger.debug("follow back remote actor")
          {:ok, follower_actor} = ActivityPub.Actor.get_cached_by_ap_id(follower)
          ActivityPub.follow(followed_actor, follower_actor)
          {:ok, _} = Kazarma.RoomType.ApUser.create_outbox(follower_actor)
        end

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
    Logger.debug("received Undo/Follow")

    case ActivityPub.Actor.get_cached_by_ap_id(followed) do
      {:ok, %ActivityPub.Actor{local: true} = followed_actor} ->
        if followed == Address.relay_ap_id() do
          Logger.debug("unfollow back remote actor")
          {:ok, follower_actor} = ActivityPub.Actor.get_cached_by_ap_id(follower)
          ActivityPub.unfollow(followed_actor, follower_actor)
          {:ok, _} = Kazarma.RoomType.ApUser.deactivate_outbox(follower_actor)
        end

      _ ->
        :error
    end
  end

  def handle_activity(%Object{} = object) do
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (other activity)")
    Logger.ap_input(object)
    Logger.debug(inspect(object))

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

  @impl ActivityPub.Adapter
  def actor_html(conn, _username) do
    # KazarmaWeb.ActorController.show(conn, %{"username" => username})
    conn
  end

  @impl ActivityPub.Adapter
  def object_html(conn, _uuid) do
    # KazarmaWeb.ObjectController.show(conn, %{"uuid" => uuid})
    conn
  end

  defp set_if_changed(previous_value, new_value, _update_fun)
       when previous_value == new_value or is_nil(new_value),
       do: nil

  defp set_if_changed(_previous_value, new_value, update_fun), do: update_fun.(new_value)
end
