defmodule Kazarma.ActivityPub.Actor do
  @moduledoc """
  Functions concerning ActivityPub actors.
  """
  alias ActivityPub.Actor
  alias KazarmaWeb.Endpoint
  alias KazarmaWeb.Router.Helpers, as: Routes
  require Logger

  def build_actor_from_data(
        %{"id" => ap_id, "preferredUsername" => local_username} = ap_data,
        keys
      ) do
    %Actor{
      local: true,
      deactivated: false,
      username: "#{local_username}@#{Application.fetch_env!(:activity_pub, :domain)}",
      ap_id: ap_id,
      data: ap_data,
      keys: keys
    }
  end

  def build_actor_from_profile(username, profile) do
    localpart = Kazarma.Address.get_username_localpart(username)
    ap_id = Kazarma.Address.ap_localpart_to_local_ap_id(localpart)

    avatar_url =
      profile["avatar_url"] && Kazarma.Matrix.Client.get_media_url(profile["avatar_url"])

    {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()
    build_actor(localpart, ap_id, profile["displayname"], avatar_url, keys)
  end

  def build_actor(local_username, ap_id, displayname, avatar_url, keys) do
    %Actor{
      local: true,
      deactivated: false,
      username: "#{local_username}@#{Application.fetch_env!(:activity_pub, :domain)}",
      ap_id: ap_id,
      data: build_actor_data(local_username, ap_id, displayname, avatar_url),
      keys: keys
    }
  end

  def build_actor_data(local_username, ap_id, displayname, avatar_url) do
    %{
      "preferredUsername" => local_username,
      "capabilities" => %{"acceptsChatMessages" => true},
      "id" => ap_id,
      "type" => "Person",
      "name" => displayname,
      "icon" => avatar_url && %{"type" => "Image", "url" => avatar_url},
      "followers" => Routes.activity_pub_url(Endpoint, :followers, local_username),
      "followings" => Routes.activity_pub_url(Endpoint, :following, local_username),
      "inbox" => Routes.activity_pub_url(Endpoint, :inbox, local_username),
      "outbox" => Routes.activity_pub_url(Endpoint, :noop, local_username),
      "manuallyApprovesFollowers" => false,
      endpoints: %{
        "sharedInbox" => Routes.activity_pub_url(Endpoint, :inbox)
      }
    }
  end

  def set_displayname(actor, displayname) do
    %{actor | data: put_in(actor.data, ["name"], displayname)}
  end

  def set_avatar_url(actor, avatar_url) do
    %{actor | data: put_in(actor.data, ["icon"], %{"type" => "Image", "url" => avatar_url})}
  end

  def get_by_matrix_id(matrix_id) do
    case Kazarma.Address.parse_matrix_id(matrix_id) do
      {:puppet, sub_localpart, sub_domain} ->
        ActivityPub.Actor.get_or_fetch_by_username("#{sub_localpart}@#{sub_domain}")

      {:local, localpart} ->
        ActivityPub.Actor.get_by_username(localpart)

      {:remote, localpart, remote_domain} ->
        ActivityPub.Actor.get_or_fetch_by_username(
          "#{localpart}=#{remote_domain}@#{Kazarma.Address.domain()}"
        )

      {:error, :invalid_address} ->
        {:error, :invalid_address}
    end
  end

  def get_from_matrix(username) do
    case Kazarma.Address.ap_username_to_matrix_id(username, [:remote_matrix, :local_matrix]) do
      {:ok, matrix_id} ->
        case Kazarma.Matrix.Bridge.get_user_by_local_id(matrix_id) do
          %{data: %{"ap_data" => ap_data, "keys" => keys}} ->
            Logger.debug("user found in database")
            {:ok, build_actor_from_data(ap_data, keys)}

          _ ->
            Logger.debug("user not found in database")

            with {:ok, profile} <- Kazarma.Matrix.Client.get_profile(matrix_id),
                 Logger.debug("user found in Matrix"),
                 actor <- build_actor_from_profile(username, profile),
                 {:ok, _} <-
                   Kazarma.Matrix.Bridge.create_user(%{
                     local_id: matrix_id,
                     remote_id: actor.ap_id,
                     data: %{"ap_data" => actor.data, "keys" => actor.keys}
                   }) do
              {:ok, actor}
            else
              _ -> {:error, :not_found}
            end
        end

      _ ->
        {:error, :not_found}
    end
  end
end
