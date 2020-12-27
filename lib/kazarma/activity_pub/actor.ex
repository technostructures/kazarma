defmodule Kazarma.ActivityPub.Actor do
  alias ActivityPub.Actor
  alias KazarmaWeb.Router.Helpers, as: Routes
  alias KazarmaWeb.Endpoint

  def build_actor(username, ap_id, matrix_profile, bridge_user) do
    %Actor{
      local: true,
      deactivated: false,
      username: "#{username}@#{Application.fetch_env!(:activity_pub, :domain)}",
      ap_id: ap_id,
      data: %{
        "preferredUsername" => username,
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
      keys: bridge_user.data["keys"]
    }
  end
end
