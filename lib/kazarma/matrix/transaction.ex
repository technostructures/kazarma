# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Transaction do
  @moduledoc """
  Implementation of `MatrixAppService.Adapter.Transaction`.
  """
  @behaviour MatrixAppService.Adapter.Transaction
  require Logger
  alias Kazarma.Matrix.Bridge
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

  def new_event(%Event{type: "m.room.message", room_id: room_id} = event) do
    Logger.debug("Received m.room.message from Synapse")

    if !is_tagged_message(event) do
      # room = Bridge.get_room_by_local_id(room_id) || Bridge.create_room(local_id: room_id, )
      case Bridge.get_room_by_local_id(room_id) do
        %Room{data: %{"type" => "chat_message"}} = room ->
          Kazarma.ActivityPub.Activity.ChatMessage.forward_to_activitypub(event, room)

        %Room{data: %{"type" => "note"}} = room ->
          Kazarma.ActivityPub.Activity.Note.forward_to_activitypub(event, room)

        nil -> :ok
      end
    end

    :ok
  rescue
    # for development, we prefere acknowledging transactions even if processing them fails
    err ->
      Logger.error(Exception.format(:error, err, __STACKTRACE__))
      :ok
  end

  def new_event(%Event{
        type: "m.room.member",
        content: content,
        room_id: room_id,
        sender: sender_id,
        state_key: user_id
      }) do
    case Kazarma.Address.matrix_id_to_actor(user_id) do
      {:ok, %ActivityPub.Actor{local: true} = actor} ->
        bridge_profile_change(user_id, actor, content)

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
    Kazarma.ActivityPub.Activity.ChatMessage.accept_puppet_invitation(user_id, room_id)
    Kazarma.Matrix.Client.put_new_direct_room_data(user_id, sender_id, room_id)
  end

  defp accept_puppet_invitation(user_id, _sender_id, room_id, %{"membership" => "invite"}) do
    Kazarma.ActivityPub.Activity.Note.accept_puppet_invitation(user_id, room_id)
  end

  defp accept_puppet_invitation(_user_id, _sender_id, _room_id, _event_content), do: :ok

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

      Kazarma.Matrix.Bridge.get_user_by_remote_id(actor.ap_id)
      |> Kazarma.Matrix.Bridge.update_user(%{
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
end
