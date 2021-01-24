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
    regex = ~r/@(?<localpart>[a-z0-9_\.-=]+):(?<domain>[a-z0-9\.-]+)/
    sub_regex = ~r/ap_(?<localpart>[a-z0-9_\.-]+)=(?<domain>[a-z0-9\.-]+)/
    # Logger.error(inspect(matrix_id))

    domain = ActivityPub.domain()

    case Regex.named_captures(regex, matrix_id) do
      %{"localpart" => localpart, "domain" => ^domain} ->
        # local Matrix user
        case Regex.named_captures(sub_regex, localpart) do
          %{"localpart" => sub_localpart, "domain" => sub_domain} ->
            # bridged ActivityPub user
            ActivityPub.Actor.get_or_fetch_by_username("#{sub_localpart}@#{sub_domain}")

          nil ->
            # real local user
            ActivityPub.Actor.get_cached_by_username(localpart)
        end

      %{"localpart" => localpart, "domain" => remote_domain} ->
        # remote Matrix user
        # TODO
        {:error, :not_implemented_yet}

      nil ->
        {:error, :invalid_address}
    end
  end
end
