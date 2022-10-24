# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ActorView do
  use KazarmaWeb, :view

  def display_name(%ActivityPub.Actor{data: %{"name" => name}}), do: name

  def ap_username(%ActivityPub.Actor{username: username}), do: username

  def matrix_username(%ActivityPub.Actor{username: username}) do
    {:ok, matrix_username} = Kazarma.Address.ap_username_to_matrix_id(username)
    matrix_username
  end

  def matrix_outbox_room(%ActivityPub.Actor{username: username}) do
    {:ok, matrix_username} = Kazarma.Address.ap_username_to_matrix_id(username)
    String.replace_prefix(matrix_username, "@", "#")
  end

  def matrix_to(actor), do: "https://matrix.to/#/#{matrix_username(actor)}"

  def matrix_scheme_user(actor),
    do: {:matrix, "u/#{matrix_username(actor) |> String.trim_leading("@")}"}

  def matrix_scheme_room(room),
    do: {:matrix, "r/#{matrix_outbox_room(room) |> String.trim_leading("#")}"}

  def ap_id(%ActivityPub.Actor{data: %{"id" => ap_id}}), do: ap_id

  def type(%ActivityPub.Actor{local: true}), do: "Matrix"
  def type(%ActivityPub.Actor{data: %{"type" => type}}), do: "ActivityPub (#{type})"

  def avatar_url(%ActivityPub.Actor{data: data}), do: data["icon"]["url"]
end
