# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity.Event do
  @moduledoc """
  Functions for Event activities, used by Mobilizon.

  https://docs.joinmobilizon.org/contribute/activity_pub/#event_1
  """
  alias Kazarma.Logger
  alias Kazarma.Matrix.Bridge

  def forward_create_to_matrix(
        %{
          data: %{
            "to" => to,
            "object" => %{"id" => object_id, "attributedTo" => attributed_to_id} = object_data
          }
        } = _activity
      ) do
    if "https://www.w3.org/ns/activitystreams#Public" in to do
      Logger.debug("Received public Event activity")

      with {:ok, attributed_to_matrix_id} <- Kazarma.Address.ap_id_to_matrix(attributed_to_id),
           {:ok, %MatrixAppService.Bridge.Room{local_id: room_id}} <-
             Kazarma.ActivityPub.Collection.get_or_create_outbox({:ap_id, attributed_to_id}),
           Kazarma.Matrix.Client.join(attributed_to_matrix_id, room_id),
           {:ok, event_id} <-
             send_event_message(room_id, attributed_to_matrix_id, object_data),
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

  defp send_event_message(room_id, user_id, %{
         "id" => ap_id,
         "content" => description,
         "name" => name,
         "category" => category,
         "startTime" => start_time
       }) do
    {:ok, dt, _} = DateTime.from_iso8601(start_time)
    formatted_start_time = DateTime.to_string(dt)

    body = """
    ### #{name}

    #{ap_id}

    > #{description}
    """

    formatted_body = """
    <a href="#{ap_id}">
      <h3>#{name}</h3>
    </a>
    [#{category}] #{formatted_start_time}
    <p>
      #{description}
    </p>
    """

    Kazarma.Matrix.Client.send_tagged_message(room_id, user_id, {body, formatted_body})
  end
end
