# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Helpers do
  @moduledoc false

  # use KazarmaWeb, :view

  def display_name(%ActivityPub.Actor{data: %{"name" => name}}), do: name

  def ap_username(%ActivityPub.Actor{username: username}), do: "@" <> username

  def main_address(%ActivityPub.Actor{local: true} = actor), do: matrix_id(actor)

  def main_address(%ActivityPub.Actor{} = actor), do: ap_username(actor)

  def puppet_address(%ActivityPub.Actor{local: true} = actor), do: ap_username(actor)

  def puppet_address(%ActivityPub.Actor{} = actor), do: matrix_id(actor)

  def matrix_id(%ActivityPub.Actor{username: username}) do
    {:ok, matrix_id} = Kazarma.Address.ap_username_to_matrix_id(username)
    matrix_id
  end

  def matrix_outbox_room(%ActivityPub.Actor{username: username}) do
    {:ok, matrix_id} = Kazarma.Address.ap_username_to_matrix_id(username)
    String.replace_prefix(matrix_id, "@", "#")
  end

  def matrix_to(actor), do: "https://matrix.to/#/#{matrix_id(actor)}"

  def matrix_scheme_user(actor),
    do: {:matrix, "u/#{matrix_id(actor) |> String.trim_leading("@")}"}

  def matrix_scheme_room(room),
    do: {:matrix, "r/#{matrix_outbox_room(room) |> String.trim_leading("#")}"}

  def ap_id(%ActivityPub.Actor{data: %{"id" => ap_id}}), do: ap_id

  def url(%ActivityPub.Actor{data: %{"url" => url}}), do: url
  def url(%ActivityPub.Actor{data: %{"id" => ap_id}}), do: ap_id

  def type(%ActivityPub.Actor{local: true}), do: "Matrix"
  def type(%ActivityPub.Actor{data: %{"type" => type}}), do: "ActivityPub (#{type})"

  def type_icon(%ActivityPub.Actor{local: true}), do: KazarmaWeb.Components.Icon.matrix_icon(%{})

  def type_icon(%ActivityPub.Actor{}),
    do: KazarmaWeb.Components.Icon.ap_icon(%{})

  def opposite_type_icon(%ActivityPub.Actor{local: true}),
    do: KazarmaWeb.Components.Icon.ap_icon(%{})

  def opposite_type_icon(%ActivityPub.Actor{}),
    do: KazarmaWeb.Components.Icon.matrix_icon(%{})

  def puppet_type(%ActivityPub.Actor{local: true, data: %{"type" => type}}),
    do: "Kazarma/ActivityPub (#{type})"

  def puppet_type(%ActivityPub.Actor{local: false}), do: "Kazarma/Matrix"

  def avatar_url(%ActivityPub.Actor{data: data}), do: data["icon"]["url"]

  def text_content(%ActivityPub.Object{
        data: %{"content" => content}
      }) do
    HtmlSanitizeEx.markdown_html(content)
  end

  def text_content(%ActivityPub.Object{
        data: %{"source" => source}
      }) do
    HtmlSanitizeEx.markdown_html(source)
  end

  def text_content(_) do
    ""
  end

  def outbox_room(%ActivityPub.Actor{local: true}) do
    # @TODO change that when Matrix user rooms are done
    nil
  end

  def outbox_room(%ActivityPub.Actor{ap_id: ap_id, username: username}) do
    case Kazarma.Bridge.get_room_by_remote_id(ap_id) do
      %MatrixAppService.Bridge.Room{} ->
        {:ok, matrix_id} = Kazarma.Address.ap_username_to_matrix_id(username)
        String.replace_leading(matrix_id, "@", "#")

      nil ->
        nil
    end
  end
end
