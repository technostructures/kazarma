# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Transaction do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.Transaction`.
  """
  @behaviour MatrixAppService.Adapter.Transaction
  alias Kazarma.Address
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  require Logger

  @matrix_mention_regex ~r/<a href="https:\/\/matrix\.to\/#\/(?<matrix_id>.+?)">(?<display_name>.*?)<\/a>/

  @impl MatrixAppService.Adapter.Transaction
  def new_event(
        %Event{
          type: "m.room.create",
          content: %{"creator" => _creator_id}
        } = event
      ) do
    Kazarma.Logger.log_received_event(event, label: "Room creation")
  end

  def new_event(
        %Event{
          type: "m.room.name",
          content: %{"name" => _name}
        } = event
      ) do
    Kazarma.Logger.log_received_event(event, label: "Name change")
  end

  def new_event(
        %Event{
          content: %{
            "m.new_content" => _,
            "m.relates_to" => %{"rel_type" => "m.replace"},
            "org.matrix.msc1767.text" => _
          },
          type: "m.room.message"
        } = event
      ) do
    Kazarma.Logger.log_received_event(event, label: "Replace event")
  end

  def new_event(%Event{type: "m.room.message", content: content}) when content == %{}, do: :ok

  def new_event(
        %Event{
          type: "m.room.message",
          room_id: room_id,
          user_id: user_id,
          content: %{"body" => "!kazarma " <> rest, "msgtype" => "m.text"}
        } = event
      ) do
    Kazarma.Logger.log_received_event(event, label: "Bot command")

    Kazarma.Commands.handle_command(rest, room_id, user_id)

    # :ok
  end

  def new_event(%Event{type: "m.room.message", room_id: room_id} = event) do
    Kazarma.Logger.log_received_event(event, label: "Message")

    if !tagged_message?(event) do
      case Bridge.get_room_by_local_id(room_id) do
        %Room{data: %{"type" => "chat"}} = room ->
          Kazarma.RoomType.Chat.create_from_event(
            event,
            room
          )

        %Room{data: %{"type" => "direct_message"}} = room ->
          Kazarma.RoomType.DirectMessage.create_from_event(event, room)

        %Room{data: %{"type" => "ap_user"}} = room ->
          Kazarma.RoomType.ApUser.create_from_event(event, room)

        %Room{data: %{"type" => "deactivated_ap_user"}} = room ->
          Kazarma.RoomType.ApUser.create_from_event(event, room)

        %Room{data: %{"type" => "collection"}} = room ->
          Kazarma.RoomType.Collection.create_from_event(event, room)

        %Room{data: %{"type" => "matrix_user"}} = room ->
          Kazarma.RoomType.MatrixUser.create_from_event(event, room)

        nil ->
          :ok
      end
    end

    :ok
  end

  def new_event(
        %Event{
          type: "m.room.redaction",
          room_id: _room_id,
          redacts: _redacts
        } = event
      ) do
    if !tagged_redact?(event) do
      Kazarma.Logger.log_received_event(event, label: "Redaction")

      Kazarma.ActivityPub.Activity.forward_redaction(event)
    end

    :ok
  end

  def new_event(
        %Event{
          type: "m.room.member",
          content: content,
          room_id: room_id,
          sender: sender_id,
          state_key: user_id
        } = event
      ) do
    Kazarma.Logger.log_received_event(event, label: "Membership")

    case Kazarma.Address.parse_matrix_id(user_id) do
      {:activity_pub, _sub_localpart, _sub_domain} ->
        accept_puppet_invitation(user_id, sender_id, room_id, content)

      {:appservice_bot, _localpart} ->
        accept_appservice_bot_invitation(user_id, room_id, content)

      {:local_matrix, _localpart} ->
        handle_matrix_member_event(user_id, room_id, content, event)

      {:remote_matrix, _localpart, _remote_domain} ->
        handle_matrix_member_event(user_id, room_id, content, event)

      _ ->
        :ok
    end

    :ok
  end

  def new_event(%Event{} = event) do
    Kazarma.Logger.log_received_event(event, label: "Unhandled")
  end

  defp accept_appservice_bot_invitation(user_id, room_id, %{
         "membership" => "invite"
       }) do
    Kazarma.Matrix.Client.join(user_id, room_id)
  end

  defp accept_appservice_bot_invitation(_, _, _) do
    :ok
  end

  defp handle_matrix_member_event(user_id, room_id, content, event) do
    {:ok, actor} = Kazarma.Address.matrix_id_to_actor(user_id)
    bridge_profile_change(user_id, actor, content)
    handle_join(room_id, actor, event)
  end

  defp accept_puppet_invitation(user_id, sender_id, room_id, %{
         "membership" => "invite",
         "is_direct" => true
       }) do
    Kazarma.RoomType.Chat.handle_puppet_invite(user_id, sender_id, room_id)
  end

  defp accept_puppet_invitation(user_id, sender_id, room_id, %{"membership" => "invite"}) do
    # @TODO fix this: could be handled by:
    # DirectMessage: accepts and add (if none)/update bridge room
    # Collection room: accepts
    # Actor: accepts
    # MatrixUser: accepts
    # Feed: accepts
    Kazarma.RoomType.DirectMessage.handle_puppet_invite(user_id, sender_id, room_id)
  end

  defp accept_puppet_invitation(_user_id, _sender_id, _room_id, _event_content), do: :ok

  defp handle_join(room_id, joiner, %{content: %{"membership" => "join"}} = event) do
    case Bridge.get_room_by_local_id(room_id) do
      %Room{data: %{"type" => "collection"}, remote_id: group_ap_id} ->
        Kazarma.RoomType.Collection.handle_join(joiner, event, group_ap_id)

      _ ->
        nil
    end

    :ok
  end

  defp handle_join(_room_id, _follower, _content), do: nil

  defp bridge_profile_change(matrix_id, actor, content) do
    Logger.debug("bridge profile change")

    with [_ | _] = changed_profile_parts <-
           Enum.filter(content, fn
             {"displayname", displayname} ->
               displayname != actor.data["name"]

             {"avatar_url", avatar_url} ->
               Kazarma.Matrix.Client.get_media_url(avatar_url) != actor.data["icon"]["url"]

             _ ->
               false
           end),
         {:ok, profile} <- Kazarma.Matrix.Client.get_profile(matrix_id),
         [_ | _] = changed_profile_parts2 <-
           Enum.filter(changed_profile_parts, fn
             {"displayname", displayname} ->
               displayname == profile["displayname"]

             {"avatar_url", avatar_url} ->
               avatar_url == profile["avatar_url"]

             _ ->
               false
           end),
         actor <-
           Enum.reduce(changed_profile_parts2, actor, fn
             {"displayname", displayname}, acc ->
               Kazarma.ActivityPub.Actor.set_displayname(acc, displayname)

             {"avatar_url", avatar_url}, acc ->
               Kazarma.ActivityPub.Actor.set_avatar_url(
                 acc,
                 Kazarma.Matrix.Client.get_media_url(avatar_url)
               )

             _, acc ->
               acc
           end) do
      %{
        to: [actor.data["followers"], "https://www.w3.org/ns/activitystreams#Public"],
        cc: [],
        actor: actor,
        object: ActivityPub.Web.ActorView.render("actor.json", %{actor: actor})
      }
      |> Kazarma.ActivityPub.update()

      ActivityPub.Actor.set_cache(actor)

      Bridge.get_user_by_remote_id(actor.ap_id)
      |> Bridge.update_user(%{
        "data" => %{"ap_data" => actor.data, "keys" => actor.keys}
      })

      :ok
    else
      _ ->
        :ok
    end
  end

  defp tagged_message?(%Event{content: %{"body" => body}}) do
    String.ends_with?(body, " \ufeff")
  end

  defp tagged_message?(_), do: false

  defp tagged_redact?(%Event{content: %{"reason" => reason}}) do
    String.ends_with?(reason, " \ufeff")
  end

  defp tagged_redact?(_), do: false

  def get_mentions_from_event_content(%{
        "msgtype" => "m.text",
        "format" => "org.matrix.custom.html",
        "formatted_body" => formatted_body
      }) do
    Regex.scan(@matrix_mention_regex, formatted_body, capture: :all_names)
    |> Enum.map(fn [_display_name, matrix_id] ->
      case Address.matrix_id_to_actor(matrix_id) do
        {:ok, actor} -> actor
        _ -> nil
      end
    end)
    |> Enum.filter(fn actor -> !is_nil(actor) end)
  end

  def get_mentions_from_event_content(_), do: []

  def build_text_content(content, additional_mentions \\ [])

  def build_text_content(
        %{
          "msgtype" => "m.text",
          "format" => "org.matrix.custom.html",
          "formatted_body" => formatted_body
        },
        additional_mentions
      ) do
    formatted_body
    |> remove_mx_reply
    |> convert_mentions
    |> add_additional_mentions(additional_mentions)

    # |> HtmlSanitizeEx.Scrubber.scrub(Kazarma.Matrix.Scrubber) # we may need an ActivityPub.Scrubber
  end

  def build_text_content(%{"msgtype" => "m.text", "body" => body}, additional_mentions),
    do: add_additional_mentions(body, additional_mentions)

  def build_text_content(_, _), do: ""

  defp ap_mention_from_matrix_id(matrix_id) do
    case Address.matrix_id_to_actor(matrix_id) do
      {:ok, actor} ->
        ~s(<span class="h-card"><a href="#{actor.data["url"] || actor.ap_id}" class="u-url mention">@<span>#{Kazarma.ActivityPub.Activity.mention_name(actor)}</span></a></span>)

      _ ->
        case Address.matrix_id_to_ap_username(matrix_id) do
          {:ok, username} ->
            ~s(<span class="h-card">@<span>#{username}</span></span>)

          _ ->
            "@" <> matrix_id_without_at = matrix_id
            ~s(<span class="h-card">@<span>#{matrix_id_without_at}</span></span>)
        end
    end
  end

  def convert_mentions(content) do
    Regex.replace(@matrix_mention_regex, content, fn _, matrix_id, _display_name ->
      ap_mention_from_matrix_id(matrix_id)
    end)
  end

  defp remove_mx_reply(content) do
    Regex.replace(~r/\<mx\-reply\>.*\<\/mx\-reply\>/s, content, "")
  end

  # we keep the code in case we want to automatically add mentions in content,
  # but we don't use it now since it's unclear for Matrix users that the
  # content has changed and it's weird when mentioning Lemmy communities to
  # create posts.
  # Mentions still appear with a dedicated UI in Pleroma and create
  # notifications in Mastodon (because they are part of the `tag` properties of
  # objects)
  defp add_additional_mentions(content, []), do: content

  defp add_additional_mentions(content, [
         %ActivityPub.Actor{ap_id: ap_id, username: username} | rest
       ]),
       do:
         add_additional_mentions(
           ~s(<span class="h-card"><a href="#{ap_id}" class="u-url mention">@<span>#{username}</span></a></span> ) <>
             content,
           rest
         )
end
