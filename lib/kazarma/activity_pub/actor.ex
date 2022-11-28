# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Actor do
  @moduledoc """
  Functions concerning ActivityPub actors.
  """
  alias ActivityPub.Actor
  alias Kazarma.Bridge
  alias KazarmaWeb.Endpoint
  alias KazarmaWeb.Router.Helpers, as: Routes
  alias Kazarma.Logger

  import Ecto.Query

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
      username: "#{local_username}@#{Kazarma.Address.domain()}",
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
      "followers" => Routes.activity_pub_url(Endpoint, :followers, "-", local_username),
      "followings" => Routes.activity_pub_url(Endpoint, :following, "-", local_username),
      "inbox" => Routes.activity_pub_url(Endpoint, :inbox, "-", local_username),
      "outbox" => Routes.activity_pub_url(Endpoint, :noop, "-", local_username),
      "manuallyApprovesFollowers" => false,
      endpoints: %{
        "sharedInbox" => Routes.activity_pub_url(Endpoint, :inbox)
      }
    }
  end

  def build_relay_actor do
    ap_id = Routes.activity_pub_url(Endpoint, :actor, "-", "relay")
    {:ok, keys} = ActivityPub.Keys.generate_rsa_pem()

    %Actor{
      local: true,
      deactivated: false,
      username: "relay@#{Kazarma.Address.domain()}",
      ap_id: ap_id,
      data: build_relay_actor_data(ap_id),
      keys: keys
    }
  end

  def build_relay_actor_data(ap_id) do
    %{
      "preferredUsername" => "relay",
      "capabilities" => %{"acceptsChatMessages" => false},
      "id" => ap_id,
      "type" => "Application",
      "name" => "Kazarma",
      # "icon" => avatar_url && %{"type" => "Image", "url" => avatar_url},
      "followers" => Routes.activity_pub_url(Endpoint, :followers, "-", "relay"),
      "followings" => Routes.activity_pub_url(Endpoint, :following, "-", "relay"),
      "inbox" => Routes.activity_pub_url(Endpoint, :inbox),
      "outbox" => Routes.activity_pub_url(Endpoint, :noop, "-", "relay"),
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

  def get_local_actor("relay") do
    matrix_id = "@relay:#{Kazarma.Address.domain()}"

    with nil <- Bridge.get_user_by_local_id(matrix_id),
         actor <- build_relay_actor(),
         {:ok, _} <-
           Bridge.create_user(%{
             local_id: matrix_id,
             remote_id: actor.ap_id,
             data: %{"ap_data" => actor.data, "keys" => actor.keys}
           }) do
      {:ok, actor}
    else
      %{data: %{"ap_data" => ap_data, "keys" => keys}} ->
        {:ok, build_actor_from_data(ap_data, keys)}

      _ ->
        {:error, :not_found}
    end
  end

  def get_local_actor(username) do
    case Kazarma.Address.ap_username_to_matrix_id(username, [:remote_matrix, :local_matrix]) do
      {:ok, matrix_id} ->
        case Bridge.get_user_by_local_id(matrix_id) do
          %{data: %{"ap_data" => ap_data, "keys" => keys}} ->
            Logger.debug("user found in database")
            {:ok, build_actor_from_data(ap_data, keys)}

          _ ->
            Logger.debug("user not found in database")

            with {:ok, profile} <- Kazarma.Matrix.Client.get_profile(matrix_id),
                 Logger.debug("user found in Matrix"),
                 actor <- build_actor_from_profile(username, profile),
                 {:ok, _} <-
                   Bridge.create_user(%{
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

  def public_activites_for_actor(actor, offset \\ 0, limit \\ 10) do
    from(object in ActivityPub.Object,
      where: fragment("(?)->>'actor' = ?", object.data, ^actor.ap_id),
      where: fragment("(?)->>'type' = ?", object.data, ^"Note"),
      where:
        fragment("(?)->'to' \\? ?", object.data, ^"https://www.w3.org/ns/activitystreams#Public"),
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: object.inserted_at]
    )
    |> Kazarma.Repo.all()
  end
end
