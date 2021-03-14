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
    Logger.info("asked for local Matrix user #{username}")
    domain = Application.fetch_env!(:activity_pub, :domain)
    # TODO usernames can be for remote matrix users
    username = String.replace_suffix(username, "@" <> domain, "")
    matrix_id = "@#{username}:#{domain}"
    # Logger.debug(matrix_id)

    with client <- @matrix_client.client(),
         {:ok, profile} <- @matrix_client.get_profile(client, matrix_id),
         ap_id = Routes.activity_pub_url(Endpoint, :actor, username),
         bridge_user = Kazarma.Matrix.Bridge.get_user_by_remote_id(ap_id),
         actor = Kazarma.ActivityPub.Actor.build_actor(username, ap_id, profile, bridge_user) do
      {:ok, actor}
    else
      _ -> {:error, :not_found}
    end
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

    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<remote_domain>[a-z0-9\.-]+)/

    with %{"localpart" => localpart, "remote_domain" => remote_domain} <-
           Regex.named_captures(regex, username),
         {:ok, %{"user_id" => matrix_id}} <-
           @matrix_client.register(
             username: "ap_#{localpart}=#{remote_domain}",
             device_id: "KAZARMA_APP_SERVICE",
             initial_device_display_name: "Kazarma"
           ) do
      @matrix_client.put_displayname(
        @matrix_client.client(user_id: matrix_id),
        matrix_id,
        name
      )

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
    raise "not implemented"
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
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (Mastodon message)")

    Kazarma.ActivityPub.Activity.forward_note(activity)
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
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (Pleroma message)")

    Kazarma.ActivityPub.Activity.forward_chat_message(activity)
  end

  def handle_activity(%Object{} = object) do
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (other activity)")
    Logger.debug(inspect(object))

    # :ok
    raise "not implemented"
  end

  @impl true
  def get_actor_by_id(_id) do
    Logger.error("get_actor_by_id called")

    {:error, :not_found}
  end

  @impl true
  def get_follower_local_ids(_actor) do
    # []
    raise "not implemented"
  end

  @impl true
  def get_following_local_ids(_actor) do
    # []
    raise "not implemented"
  end
end
