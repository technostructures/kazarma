defmodule Kazarma.ActivityPub.Actor do
  @moduledoc """
  Functions concerning ActivityPub actors.
  """
  alias ActivityPub.Actor
  alias KazarmaWeb.Endpoint
  alias KazarmaWeb.Router.Helpers, as: Routes

  def build_actor(username, ap_id, matrix_profile, bridge_user) do
    %Actor{
      local: true,
      deactivated: false,
      username: "#{username}@#{Application.fetch_env!(:activity_pub, :domain)}",
      ap_id: ap_id,
      data: %{
        "preferredUsername" => username,
        "capabilities" => %{"acceptsChatMessages" => true},
        "id" => ap_id,
        "type" => "Person",
        "name" => matrix_profile["displayname"],
        "followers" => Routes.activity_pub_url(Endpoint, :followers, username),
        "followings" => Routes.activity_pub_url(Endpoint, :following, username),
        "inbox" => Routes.activity_pub_url(Endpoint, :inbox, username),
        "outbox" => Routes.activity_pub_url(Endpoint, :noop, username),
        "manuallyApprovesFollowers" => false,
        endpoints: %{
          "sharedInbox" => Routes.activity_pub_url(Endpoint, :inbox)
        }
      },
      # data: %{"icon" => %{"type" => "Image", "url" => } (get avatar_url
      # TODO: set avatar url that's in profile["avatar_url"]
      keys: bridge_user && bridge_user.data["keys"]
    }
  end

  def get_by_matrix_id(matrix_id) do
    case Kazarma.Address.parse_matrix_id(matrix_id) do
      {:puppet, sub_localpart, sub_domain} ->
        ActivityPub.Actor.get_or_fetch_by_username("#{sub_localpart}@#{sub_domain}")

      {:local, localpart} ->
        ActivityPub.Actor.get_cached_by_username(localpart)

      {:remote, localpart, remote_domain} ->
        ActivityPub.Actor.get_or_fetch_by_username("#{localpart}@#{remote_domain}")

      {:error, :invalid_address} ->
        {:error, :invalid_address}
    end
  end

  def get_from_matrix(username) do
    with {:ok, matrix_id} <- Kazarma.Address.ap_username_to_matrix_id(username, [:remote_matrix, :local_matrix]),
         {:ok, profile} <- Kazarma.Matrix.Client.get_profile(matrix_id),
         localpart = String.replace_suffix(username, "@#{Kazarma.Address.domain()}", ""),
         ap_id <- Kazarma.Address.ap_localpart_to_local_ap_id(localpart),
         bridge_user <- Kazarma.Matrix.Bridge.get_user_by_remote_id(ap_id),
         actor <- build_actor(localpart, ap_id, profile, bridge_user) do
      {:ok, actor}
    else
      _ -> {:error, :not_found}
    end
  end
end
