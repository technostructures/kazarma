defmodule Kazarma.ActivityPub.Adapter do
  @moduledoc """
  Implementation of `ActivityPub.Adapter`.
  """
  require Logger
  use Kazarma.Config
  @behaviour ActivityPub.Adapter

  alias ActivityPub.Actor
  alias ActivityPub.Object
  alias KazarmaWeb.Endpoint
  alias KazarmaWeb.Router.Helpers, as: Routes

  @impl ActivityPub.Adapter
  def get_actor_by_username(username) do
    Logger.debug("asked for local Matrix user #{username}")

    Kazarma.ActivityPub.Actor.get_from_matrix(username)
  end

  @impl ActivityPub.Adapter
  def update_local_actor(%Actor{ap_id: ap_id} = actor, data) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_local_actor/2")
    # Logger.debug(inspect(actor))
    # Logger.debug(inspect(data))

    {:ok, _updated} = Kazarma.Matrix.Bridge.upsert_user(%{"data" => data}, remote_id: ap_id)

    {:ok, Map.merge(actor, data)}
  end

  @impl ActivityPub.Adapter
  def maybe_create_remote_actor(%Actor{username: username, data: %{"name" => name}}) do
    Logger.debug("Kazarma.ActivityPub.Adapter.maybe_create_remote_actor/1")
    # Logger.debug(inspect(actor))

    with {localpart, remote_domain} <-
           Kazarma.Address.parse_activitypub_username(username),
         {:ok, %{"user_id" => matrix_id}} <-
           Kazarma.Matrix.Client.register_puppet(localpart, remote_domain) do
      Kazarma.Matrix.Client.set_displayname(matrix_id, name)

      :ok
    end
  end

  @impl ActivityPub.Adapter
  def update_remote_actor(%Object{} = object) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_remote_actor/1")
    # Logger.debug(inspect(object))

    # TODO: update Matrix bridged user
    # :ok <- @matrix_client.set_displayname(...),
    # :ok <- @matrix_client.set_avatar_url(...),

    # :ok
    raise "update_remote_actor/1: not implemented"
  end

  @impl ActivityPub.Adapter
  # Mastodon style message
  def handle_activity(
        %{
          data: %{"type" => "Create"},
          object: %Object{
            data: %{
              "type" => "Note"
            }
          }
        } = activity
      ) do
    Kazarma.ActivityPub.Activity.Note.forward_to_matrix(activity)
  end

  # Pleroma style message
  def handle_activity(
        %{
          data: %{
            "type" => "Create"
          },
          object: %Object{
            data: %{
              "type" => "ChatMessage"
            }
          }
        } = activity
      ) do
    Kazarma.ActivityPub.Activity.ChatMessage.forward_to_matrix(activity)
  end

  def handle_activity(%Object{} = object) do
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (other activity)")
    Logger.debug(inspect(object))

    # :ok
    raise "handle_activity/1: not implemented"
  end

  @impl true
  def get_actor_by_id(_id) do
    Logger.error("get_actor_by_id called")

    {:error, :not_found}
  end

  @impl true
  def get_follower_local_ids(_actor) do
    # []
    raise "get_follower_local_ids/1: not implemented"
  end

  @impl true
  def get_following_local_ids(_actor) do
    # []
    raise "get_following_local_ids/1: not implemented"
  end
end
