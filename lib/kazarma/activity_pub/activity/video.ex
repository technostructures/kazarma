# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity.Video do
  @moduledoc """
  Functions for Video activities, used by PeerTube.
  """
  alias ActivityPub.Object
  alias Kazarma.ActivityPub.Collection
  alias Kazarma.Address
  alias Kazarma.Matrix.Bridge
  alias Kazarma.Matrix.Client
  alias MatrixAppService.Bridge.Room
  require Logger

  def forward_create_to_matrix(%{
        data: %{"to" => to_list, "actor" => from_id},
        object: %Object{
          data: %{"id" => object_id, "attributedTo" => attributed_to} = object_data
        }
      }) do
    if "https://www.w3.org/ns/activitystreams#Public" in to_list do
      Logger.debug("Received public Video activity")

      with %{"id" => person_sender} <-
             Enum.find(attributed_to, fn
               %{"type" => "Person"} -> true
               _ -> false
             end),
           %{"id" => channel_sender} <-
             Enum.find(attributed_to, fn
               %{"type" => "Group"} -> true
               _ -> false
             end),
           attributed_list = [channel_sender, person_sender],
           {:ok, from_matrix_id} <- Address.ap_id_to_matrix(channel_sender) do
        for attributed <- attributed_list do
          with {:ok, %Room{local_id: room_id}} <-
                 Collection.get_or_create_outbox({:ap_id, attributed}),
               Client.join(from_matrix_id, room_id),
               {:ok, event_id} = send_video_message(room_id, from_matrix_id, object_data),
               {:ok, _} <-
                 Bridge.create_event(%{
                   local_id: event_id,
                   remote_id: object_id,
                   room_id: room_id
                 }) do
            :ok
          end
        end
      end
    end
  end

  defp send_video_message(room_id, user_id, %{
         "id" => ap_id,
         "content" => description,
         "name" => name,
         "duration" => _duration,
         "url" => _links,
         "icon" => icons
       }) do
    thumbnail_url = icons |> Enum.sort_by(& &1["width"]) |> List.first() |> Map.get("url")
    {:ok, thumbnail_matrix_url} = Client.upload_media(user_id, thumbnail_url)

    body = """
    ### #{name}

    #{ap_id}

    > #{description}
    """

    formatted_body = """
    <h3>#{name}</h3>
    <a href="#{ap_id}">
      <img src="#{thumbnail_matrix_url}">
    </a>
    <p>
      #{description}
    </p>
    """

    Client.send_tagged_message(room_id, user_id, {body, formatted_body})
  end
end
