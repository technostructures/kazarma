defmodule Kazarma.ActivityPub.Adapter do
  require Logger
  @behaviour ActivityPub.Adapter

  alias KazarmaWeb.Router.Helpers, as: Routes
  alias KazarmaWeb.Endpoint
  alias ActivityPub.Actor
  alias ActivityPub.Object

  @impl ActivityPub.Adapter
  def get_actor_by_username(username) do
    Logger.info("asked for local Matrix user #{username}")

    with client <- MatrixAppService.Client.client(),
         matrix_id = "@#{username}:#{Application.fetch_env!(:activity_pub, :domain)}",
         {:ok, profile} <- Polyjuice.Client.Profile.get_profile(client, matrix_id),
         _ = Logger.error(inspect(profile)),
         ap_id = Routes.activity_pub_url(Endpoint, :actor, username),

         actor = %Actor{
           local: true,
           username: username,
           ap_id: ap_id,
           data: %{
             "preferredUsername" => username,
             "id" => ap_id,
             "type" => "Person",
             "name" => profile["displayname"],
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
           # TODO: get keys from account_data
           keys: "-----BEGIN RSA PRIVATE KEY-----\nMIIEogIBAAKCAQEAn7Y80xITX+xTzdbdcYrQa15ct/57jaQBQUgo/zj64dVJn2Qv\nXSeQG5COYMD13IKu1GeeTR80XWela/hiSJNQFZdBcHScFND7gLHpBYthXE2B4196\nuhlpMMBs4yKYep6EPHCWi43hZksByEIvB9CM+jww6hPcddyvyGUjR2LxPKtJFbmW\njv0JeyTX64Wp1Zj5CDSnZpD148RgvnTQq4aPZ0Rf2HiiCLiuz0FlSAPiyn5oIsx/\nPOAFuYjVP5dioQBeJ5NeMUEsGnigfCL9u9bQ3O5Dqv4E/rDGDGca+q1V0mjaVXed\nKFIMtUpia8XDA4vVu9m8VbDdAfOexqK+9s6auQIDAQABAoIBAA2PL0LMOhDew46q\nO0q0elVjQYPtexffYKvmMHTapZIexY1euBa0kSuF7lCQkU8TWTx3P51UlOGJNyYf\nhFidCSOMH+YoQEgUJgYbFKl/19g6TFi9dnHuTlvxOk1eVouygY+QD3fxp71DiPcz\nh0KmlhF4or58yS7IebQNwh0BbXG1BrhrvMBS1tz8UWkpEMIhnlMPYFxQ2iHpYYi8\n0vAyMKeTnxRGRO7FkBHA/uwUMKYNFkVBvNpJwqbPApl/0mSra4+3AntFOkbR363A\n+rPWSlt6wActqCpYgAdOqB+O1na4Xt3oPLoy4N5zC2J0fACJ5v5ixsIvZxbVOZKT\nj2IvDgECgYEA0Xe3FlE9E7i25dwqX9ruCVZNx9ZozGDyyL98VtZzoosnUhEtPMPW\nyTRzLGAm9XMIIK9of2RvKcjOjupnZ3pVSUQakMN9lQXrMVaSbI/0SHWuCf9RetrJ\nsX05+etfbDAwLljfvDW2V6QG9jIVKskXAjsX8uw1gAuI9tRa9lnNz2kCgYEAwzDx\n4iXX7DKMM7HADgTdV6V+Lli0eOOlcxcnygblnLiUvejpbj040TUqlFMD6QFvdG7K\nC3BWf4ak3Hx169pkZkYu5riuidPDbVLO74vogVQPSxDRj9hqYDVs1VE9Ems/OWiq\nh5N6QT65rR9gysrXIAzqCfdHCX1NvjlzrdjjVtECgYAzZPw3LZeezyORIoQDIORm\nxhYvghwUiXUIbHNFmzikGSB8slo3HpYEqCnaKX1lm+PSoTcyiqH7zplf14OnkAx8\n/YjHHDAj8F/UqzkiCfAWF0msikijrCrwsZkYCPhQw0IPHR9IPqWOu2A55+/pn41V\nrsohgHNgB3SDm3b2GvK0gQKBgAfp1xSlFiD0V6zM2w12cwbXpcr5O6/fAtksqidN\nqkd1UEp2w+f9QW1x610CFJmAvmUJDNXz4v3elpZ90UYTn5hp5gLin+jklfq7rboW\ngQGlR81yTBy52G44HEZ1ubUidfi83pUKjJ1SjrKPIBx4psoc2+w1g0LGOr2olKEK\ntwTRAoGAdvzEgdwT3pmadejSYxtwWcDGaEqGF3CJ+2726KIKAhK86O3TumviyEYn\nm0LT0jsLCifXzeX6JrPrHbqCZF7TrEMc13FR8GRQoqfTxT1lwRDzKPlOPnfDIHKd\npq9g1Fh3/KxoVqohllp7oYIfWw76VD2m0PTnIcAWAVvz/HkiO8o=\n-----END RSA PRIVATE KEY-----"
         } do
      {:ok, actor}
    else
      _ -> {:error, :not_found}
    end
  end

  @impl ActivityPub.Adapter
  def update_local_actor(%Actor{username: username, data: data} = actor, new_data) do
    Logger.error("new data =>")
    Logger.error(inspect(new_data))

    # TODO: this is used to set private key, store in account_data
    # MatrixAppService.Client.set_account_data("activity_pub_key", key, user_id: matrix_id)

    {:ok, Map.merge(actor, new_data)}
  end

  @impl ActivityPub.Adapter
  def maybe_create_remote_actor(%Actor{} = actor) do
    Logger.error("should create new remote actor")
    Logger.error(inspect(actor))

    # with {:ok, _matrix_id} <-
    #   MatrixAppService.Client.register(
    #     username: "ap_#{localpart}=#{remote_domain}",
    #     device_id: "KAZARMA_APP_SERVICE",
    #     initial_device_display_name: "Kazarma"
    #   ) do

    # TODO: create Matrix bridged user

    :ok
  end

  @impl ActivityPub.Adapter
  def update_remote_actor(%Object{} = object) do
    Logger.error("should update remote actor")
    Logger.error(inspect(object))

    # TODO: update Matrix bridged user
    # :ok <- MatrixAppService.Client.set_displayname(...),
    # :ok <- MatrixAppService.Client.set_avatar_url(...),

    :ok
  end

  @impl ActivityPub.Adapter
  def handle_activity(%Object{} = object) do
    Logger.error("should handle activity")
    Logger.error(inspect(object))

    # TODO: send Matrix event

    :ok
  end
end
