defmodule Kazarma.ActivityPub.Adapter do
  require Logger
  @behaviour ActivityPub.Adapter

  alias Kazarma.Address
  alias KazarmaWeb.Router.Helpers, as: Routes
  alias KazarmaWeb.Endpoint
  alias ActivityPub.Actor
  alias ActivityPub.Object

  defp matrix_client() do
    Application.get_env(:kazarma, :matrix)
    |> Keyword.fetch!(:client)
  end

  @impl ActivityPub.Adapter
  def get_actor_by_username(username) do
    Logger.info("asked for local Matrix user #{username}")
    domain = Application.fetch_env!(:activity_pub, :domain)
    # TODO usernames can be for remote matrix users
    username = String.replace_suffix(username, "@" <> domain, "")
    matrix_id = "@#{username}:#{domain}"

    with client <- matrix_client().client(),
         {:ok, profile} <- matrix_client().get_profile(client, matrix_id),
         # _ = Logger.debug(inspect(profile)),
         # {:ok, private_key} <- ActivityPub.Keys.generate_rsa_pem(),
         ap_id = Routes.activity_pub_url(Endpoint, :actor, username),
         bridge_user = Kazarma.Matrix.Bridge.get_user_by_remote_id(ap_id),
         actor = %Actor{
           local: true,
           deactivated: false,
           username: "#{username}@#{Application.fetch_env!(:activity_pub, :domain)}",
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
           # nil # private_key
           keys: bridge_user.data["keys"]
         } do
      {:ok, actor}
    else
      _ -> {:error, :not_found}
    end
  end

  @impl ActivityPub.Adapter
  def update_local_actor(%Actor{ap_id: ap_id} = actor, new_data) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_local_actor/2")
    Logger.debug(inspect(actor))
    Logger.debug(inspect(new_data))

    {:ok, _updated} = Kazarma.Matrix.Bridge.upsert_user(%{"data" => new_data}, remote_id: ap_id)

    {:ok, Map.merge(actor, new_data)}
  end

  @impl ActivityPub.Adapter
  def maybe_create_remote_actor(%Actor{username: username, data: %{"name" => name}}) do
    Logger.debug("Kazarma.ActivityPub.Adapter.maybe_create_remote_actor/1")
    # Logger.debug(inspect(actor))

    regex = ~r/(?<localpart>[a-z0-9_\.-]+)@(?<remote_domain>[a-z0-9\.-]+)/

    with %{"localpart" => localpart, "remote_domain" => remote_domain} <-
           Regex.named_captures(regex, username),
         {:ok, %{"user_id" => matrix_id}} <-
           matrix_client().register(
             username: "ap_#{localpart}=#{remote_domain}",
             device_id: "KAZARMA_APP_SERVICE",
             initial_device_display_name: "Kazarma"
           ) do
      matrix_client().modify_displayname(
        matrix_client().client(user_id: matrix_id),
        matrix_id,
        name
      )

      :ok
    end
  end

  @impl ActivityPub.Adapter
  def update_remote_actor(%Object{} = object) do
    Logger.debug("Kazarma.ActivityPub.Adapter.update_remote_actor/1")
    Logger.debug(inspect(object))

    # TODO: update Matrix bridged user
    # :ok <- matrix_client().set_displayname(...),
    # :ok <- matrix_client().set_avatar_url(...),

    :ok
  end

  @impl ActivityPub.Adapter
  # Mastodon style message
  def handle_activity(%{
        data: %{"type" => "Create"},
        object: %Object{
          data: %{
            "type" => "Note",
            "content" => _body,
            "actor" => _from_id,
            "context" => _context,
            "conversation" => _conversation
          }
        }
      }) do
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (Mastodon message)")

    :ok
  end

  # Pleroma style message
  def handle_activity(%{
        data: %{
          "type" => "Create",
          "actor" => from_id,
          "to" => [to_id]
          # "object" => %{
          #   "type" => "ChatMessage",
          #   "content" => body,
          #   "actor" => from_id,
          #   "to" => [to_id]
        },
        object: %Object{
          data: %{
            "type" => "ChatMessage",
            "content" => body
          }
        }
      }) do
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (Pleroma message)")

    with {:ok, room_id} <-
           get_or_create_direct_chat(from_id, to_id),
         {:ok, _} <-
           matrix_client().send_message(room_id, {body <> " \ufeff", body <> " \ufeff"},
             user_id: Address.ap_to_matrix(from_id)
           ) do
      :ok
    else
      {:error, _code, %{"error" => error}} -> Logger.error(error)
      {:error, error} -> Logger.error(inspect(error))
    end
  end

  def handle_activity(%Object{} = object) do
    Logger.debug("Kazarma.ActivityPub.Adapter.handle_activity/1 (other activity)")
    Logger.debug(inspect(object))

    :ok
  end

  defp get_or_create_direct_chat(from_ap_id, to_ap_id) do
    from_matrix_id = Address.ap_to_matrix(from_ap_id)
    to_matrix_id = Address.ap_to_matrix(to_ap_id)
    Logger.debug("from " <> inspect(from_matrix_id) <> " to " <> inspect(to_matrix_id))

    with {:error, :not_found} <-
           get_direct_room(from_matrix_id, to_matrix_id),
         {:ok, %{"room_id" => room_id}} <-
           matrix_client().create_room(
             [
               visibility: :private,
               name: nil,
               topic: nil,
               is_direct: true,
               invite: [to_matrix_id],
               room_version: "5"
             ],
             user_id: from_matrix_id
           )
           |> IO.inspect(),
         {:ok, _} <-
           Kazarma.Matrix.Bridge.create_room(%{
             local_id: room_id,
             data: %{type: :chat_message, to_ap: from_ap_id}
           })
           |> IO.inspect() do
      {:ok, room_id}
    else
      {:ok, room_id} -> {:ok, room_id}
      {:error, error} -> {:error, error}
    end
  end

  defp get_direct_room(from_matrix_id, to_matrix_id) do
    with {:ok, data} <-
           matrix_client().get_data(
             matrix_client().client(user_id: to_matrix_id),
             to_matrix_id,
             "m.direct"
           ),
         _ = Logger.debug("weird: " <> inspect(data)),
         %{^from_matrix_id => [room_id | _]} <- data do
      {:ok, room_id}
    else
      {:error, 404, _error} ->
        {:error, :not_found}

      data when is_map(data) ->
        {:error, :not_found}
    end
  end
end
