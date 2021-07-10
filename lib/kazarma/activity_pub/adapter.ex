defmodule Kazarma.ActivityPub.Adapter do
  @moduledoc """
  Implementation of `ActivityPub.Adapter`.
  """
  require Logger
  use Kazarma.Config
  @behaviour ActivityPub.Adapter

  alias ActivityPub.Actor
  alias ActivityPub.Object

  @impl ActivityPub.Adapter
  def get_actor_by_username(username) do
    Logger.debug("asked for local Matrix user #{username}")

    Kazarma.ActivityPub.Actor.get_from_matrix(username)
  end

  @impl ActivityPub.Adapter
  def update_local_actor(%Actor{ap_id: ap_id} = actor, data) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_local_actor/2")
    Logger.error("this should no longer happen")
    Logger.debug(inspect(actor))
    Logger.debug(inspect(data))

    {:ok, actor}
  end

  @impl ActivityPub.Adapter
  def maybe_create_remote_actor(%Actor{username: username, data: %{"name" => name} = data}) do
    Logger.debug("Kazarma.ActivityPub.Adapter.maybe_create_remote_actor/1")
    # Logger.debug(inspect(actor))

    with {:ok, matrix_id} = Kazarma.Address.ap_username_to_matrix_id(username, [:remote]),
         {:ok, %{"user_id" => matrix_id}} <-
           Kazarma.Matrix.Client.register(matrix_id) do
      Kazarma.Matrix.Client.put_displayname(matrix_id, name)
      avatar_url = get_in(data, ["icon", "url"])
      if avatar_url, do: Kazarma.Matrix.Client.upload_and_set_avatar(matrix_id, avatar_url)

      :ok
    end
  end

  @impl ActivityPub.Adapter
  def update_remote_actor(
        %Ecto.Changeset{changes: %{data: changes}, data: %{data: previous}} = changeset
      ) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_remote_actor/1")
    Logger.debug(inspect(changeset))

    {:ok, matrix_id} = Kazarma.Address.ap_id_to_matrix(previous["id"])

    set_if_changed(previous["name"], changes["name"], fn name ->
      Kazarma.Matrix.Client.put_displayname(matrix_id, name)
    end)

    set_if_changed(previous["icon"]["url"], changes["icon"]["url"], fn avatar_url ->
      Kazarma.Matrix.Client.upload_and_set_avatar(matrix_id, avatar_url)
    end)

    :ok
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
  def base_url, do: Application.get_env(:activity_pub, :base_url)

  @impl true
  def domain, do: Application.get_env(:activity_pub, :domain)

  @impl true
  def get_redirect_url(_id_or_username) do
    raise "get_redirect_url/1: not implemented"
  end

  defp set_if_changed(previous_value, new_value, _update_fun)
       when previous_value == new_value or is_nil(new_value),
       do: nil

  defp set_if_changed(_previous_value, new_value, update_fun), do: update_fun.(new_value)
end
