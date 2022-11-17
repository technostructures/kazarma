# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Transaction do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.Transaction`.
  """
  @behaviour MatrixAppService.Adapter.Transaction
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias MatrixAppService.Bridge.Room
  alias MatrixAppService.Event

  @impl MatrixAppService.Adapter.Transaction
  def new_event(%Event{
        type: "m.room.create",
        content: %{"creator" => creator_id}
      }) do
    Logger.debug("Room creation by #{creator_id}")
  end

  def new_event(%Event{
        type: "m.room.name",
        content: %{"name" => name}
      }) do
    Logger.debug("Attributing name #{name}")
  end

  def new_event(%Event{
        content: %{
          "m.new_content" => _,
          "m.relates_to" => %{"rel_type" => "m.replace"},
          "org.matrix.msc1767.text" => _
        },
        type: "m.room.message"
      }) do
    Logger.debug("Replace message event")
  end

  def new_event(%Event{type: "m.room.message", content: content}) when content == %{}, do: :ok

  def new_event(%Event{type: "m.room.message", room_id: room_id} = event) do
    Logger.info("Received m.room.message from Synapse")
    Logger.matrix_input(event)

    if !is_tagged_message(event) do
      text_content = build_text_content(event.content)

      case Bridge.get_room_by_local_id(room_id) do
        %Room{data: %{"type" => "chat"}} = room ->
          Kazarma.RoomType.Chat.create_from_matrix(
            event,
            room,
            text_content
          )

        %Room{data: %{"type" => "direct_message"}} = room ->
          Kazarma.RoomType.DirectMessage.create_from_matrix(event, room, text_content)

        %Room{data: %{"type" => "actor_outbox"}} = room ->
          Kazarma.RoomType.ActorOutbox.create_from_matrix(event, room, text_content)

        %Room{data: %{"type" => "collection"}} = room ->
          Kazarma.RoomType.Collection.create_from_matrix(event, room, text_content)

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
    if !is_tagged_redact(event) do
      Logger.debug("Processing m.room.redaction event")

      Kazarma.ActivityPub.Activity.forward_redaction(event)
    end

    :ok
  end

  def new_event(%Event{
        type: "m.room.member",
        content: %{"membership" => "leave"},
        room_id: room_id,
        state_key: user_id
      }) do
    case Kazarma.Address.matrix_id_to_actor(user_id) do
      {:ok, %ActivityPub.Actor{local: true} = _follower} ->
        case Bridge.get_room_by_local_id(room_id) do
          %Room{data: %{"type" => "actor_outbox"}, remote_id: followed_ap_id} ->
            {:ok, _followed} = ActivityPub.Actor.get_or_fetch_by_ap_id(followed_ap_id)

          _ ->
            nil
        end

      _ ->
        :ok
    end
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
    case Kazarma.Address.matrix_id_to_actor(user_id) do
      {:ok, %ActivityPub.Actor{local: true} = actor} ->
        bridge_profile_change(user_id, actor, content)
        maybe_follow_or_accept(room_id, actor, event)

      {:ok, %ActivityPub.Actor{local: false}} ->
        accept_puppet_invitation(user_id, sender_id, room_id, content)

      _ ->
        :ok
    end

    :ok
  end

  def new_event(%Event{type: type} = event) do
    Logger.debug("Received #{type} from Synapse")
    Logger.debug(inspect(event))
  end

  defp accept_puppet_invitation(user_id, sender_id, room_id, %{
         "membership" => "invite",
         "is_direct" => true
       }) do
    Kazarma.RoomType.Chat.handle_puppet_invite(user_id, sender_id, room_id)
  end

  defp accept_puppet_invitation(user_id, _sender_id, room_id, %{"membership" => "invite"}) do
    # @TODO fix this: could be handled by:
    # DirectMessage: accepts and add (if none)/update bridge room
    # Collection room: accepts
    # Actor: accepts
    # MatrixUser: accepts
    # Feed: accepts
    Kazarma.RoomType.DirectMessage.handle_puppet_invite(user_id, room_id)
  end

  defp accept_puppet_invitation(_user_id, _sender_id, _room_id, _event_content), do: :ok

  # @TODO separate in 2 functions
  defp maybe_follow_or_accept(room_id, joiner, %{content: %{"membership" => "join"}} = event) do
    case Bridge.get_room_by_local_id(room_id) do
      %Room{data: %{"type" => "actor_outbox"}, remote_id: followed_ap_id} ->
        {:ok, followed} = ActivityPub.Actor.get_or_fetch_by_ap_id(followed_ap_id)
        Kazarma.ActivityPub.follow(joiner, followed)

      %Room{data: %{"type" => "collection"}, remote_id: group_ap_id} ->
        with %{
               unsigned: %{
                 "prev_content" => %{"membership" => "invite"},
                 "replaces_state" => invite_event_id
               }
             } <- event,
             %BridgeEvent{remote_id: invite_ap_id} <-
               Bridge.get_event_by_local_id(invite_event_id) do
          Kazarma.ActivityPub.accept(%{
            to: [group_ap_id],
            object: invite_ap_id,
            actor: joiner
          })
        end

      _ ->
        nil
    end
  end

  defp maybe_follow_or_accept(_room_id, _follower, _content), do: nil

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
        object: ActivityPubWeb.ActorView.render("actor.json", %{actor: actor})
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

  defp is_tagged_message(%Event{content: %{"body" => body}}) do
    String.ends_with?(body, " \ufeff")
  end

  defp is_tagged_message(_), do: false

  defp is_tagged_redact(%Event{content: %{"reason" => reason}}) do
    String.ends_with?(reason, " \ufeff")
  end

  defp is_tagged_redact(_), do: false

  defp build_text_content(%{
         "msgtype" => "m.text",
         "format" => "org.matrix.custom.html",
         "formatted_body" => formatted_body
       }) do
    formatted_body
    |> remove_mx_reply
    |> convert_mentions

    # |> HtmlSanitizeEx.Scrubber.scrub(Kazarma.Matrix.Scrubber) # we may need an ActivityPub.Scrubber
  end

  defp build_text_content(%{"msgtype" => "m.text", "body" => body}), do: body

  defp build_text_content(_), do: ""

  defp ap_mention_from_matrix_id(matrix_id) do
    case Address.matrix_id_to_actor(matrix_id) do
      {:ok, actor} ->
        ~s(<span class="h-card"><a href="#{actor.ap_id}" class="u-url mention">@<span>#{actor.username}</span></a></span>)

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
    ap_mention_regex =
      ~r/<a href="https:\/\/matrix\.to\/#\/(?<matrix_id>.+?)">(?<display_name>.*?)<\/a>/

    Regex.replace(ap_mention_regex, content, fn _, matrix_id, _display_name ->
      ap_mention_from_matrix_id(matrix_id)
    end)
  end

  defp remove_mx_reply(content) do
    Regex.replace(~r/\<mx\-reply\>.*\<\/mx\-reply\>/s, content, "")
  end
end
