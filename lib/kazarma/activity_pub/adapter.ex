# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Adapter do
  @moduledoc """
  Implementation of `ActivityPub.Adapter`.
  """
  alias Kazarma.Logger
  use Kazarma.Config
  @behaviour ActivityPub.Adapter

  alias Kazarma.Address
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias ActivityPub.Actor
  alias ActivityPub.Object
  alias KazarmaWeb.Router.Helpers, as: Routes

  @impl ActivityPub.Adapter
  def get_actor_by_username(username) do
    Logger.debug("asked for local Matrix user #{username}")

    Kazarma.ActivityPub.Actor.get_from_matrix(username)
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
        Kazarma.Matrix.Bridge.create_user(%{
          local_id: matrix_id,
          remote_id: ap_id,
          data: %{}
        })

      # should we always create a corresponding timeline room?
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

    with %{local_id: matrix_id} <- Kazarma.Matrix.Bridge.get_user_by_remote_id(previous["id"]) do
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
  # Mastodon style message
  def handle_activity(
        %{
          data: %{"type" => "Create"},
          object:
            %Object{
              data: %{
                "type" => "Note"
              }
            } = object
        } = activity
      ) do
    Logger.ap_input(activity)
    Logger.ap_input(object)

    case Kazarma.ActivityPub.Activity.Note.forward_create_to_matrix(activity) do
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

  # Pleroma style message
  def handle_activity(
        %{
          data: %{
            "type" => "Create"
          },
          object:
            %Object{
              data: %{
                "type" => "ChatMessage"
              }
            } = object
        } = activity
      ) do
    Logger.ap_input(activity)
    Logger.ap_input(object)
    Kazarma.ActivityPub.Activity.ChatMessage.forward_create_to_matrix(activity)
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
           Kazarma.Matrix.Bridge.get_event_by_remote_id(object_ap_id),
         {:ok, delete_event_id} <-
           Kazarma.Matrix.Client.redact_message(
             sender_matrix_id,
             room_id,
             event_id
           ) do
      Kazarma.Matrix.Bridge.create_event(%{
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

  # Video
  def handle_activity(
        %{
          data: %{
            "type" => "Create"
          },
          object: %Object{
            data: %{
              "type" => "Video"
            }
          }
        } = activity
      ) do
    Kazarma.ActivityPub.Activity.Video.forward_create_to_matrix(activity)
  end

  # Event
  def handle_activity(
        %{
          data: %{
            "type" => "Create",
            "object" => %{
              "type" => "Event"
            }
          }
        } = activity
      ) do
    Logger.debug("received Create Event activity")
    Kazarma.ActivityPub.Activity.Event.forward_create_to_matrix(activity)
  end

  def handle_activity(
        %{
          data: %{
            "type" => "Announce",
            "object" => object_ap_id
          }
        } = activity
      ) do
    case ActivityPub.Object.get_or_fetch_by_ap_id(object_ap_id) do
      {:ok, %Object{data: %{"type" => "Event"}} = object} ->
        Kazarma.ActivityPub.Activity.Event.forward_announce_to_matrix(activity, object)

      _ ->
        Logger.debug("unhandled Announce activity")
    end
  end

  # Instance following (Mobilizon style)
  def handle_activity(%{
        data: %{
          "type" => "Follow",
          "actor" => remote_relay_ap_id,
          "object" => local_relay_ap_id
        }
      }) do
    Logger.debug("try following back remote relay")

    if local_relay_ap_id ==
         Routes.activity_pub_url(Endpoint, :actor, "relay") do
      Logger.debug("following back remote relay")
      {:ok, local_relay} = ActivityPub.Actor.get_cached_by_ap_id(local_relay_ap_id)
      {:ok, remote_relay} = ActivityPub.Actor.get_cached_by_ap_id(remote_relay_ap_id)
      ActivityPub.follow(local_relay, remote_relay)
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
  def actor_html(conn, username) do
    KazarmaWeb.ActorController.show(conn, %{"username" => username})
  end

  @impl ActivityPub.Adapter
  def object_html(conn, uuid) do
    KazarmaWeb.ObjectController.show(conn, %{"uuid" => uuid})
  end

  defp set_if_changed(previous_value, new_value, _update_fun)
       when previous_value == new_value or is_nil(new_value),
       do: nil

  defp set_if_changed(_previous_value, new_value, update_fun), do: update_fun.(new_value)
end
