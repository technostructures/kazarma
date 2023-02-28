# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity do
  @moduledoc """
  Activity-related functions.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Logger
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias Kazarma.Matrix.Client
  alias MatrixAppService.Event

  import Ecto.Query

  def create_from_event(
        event,
        params
      ) do
    sender = Keyword.fetch!(params, :sender)

    to = Keyword.fetch!(params, :to)

    type = Keyword.get(params, :type, "Note")

    replied_activity =
      get_replied_activity_if_exists(event) || Keyword.get(params, :fallback_reply)

    in_reply_to = make_in_reply_to(replied_activity)

    context = Keyword.get(params, :context) || make_context(replied_activity, sender)

    attachment = attachment_from_matrix_event_content(event.content)

    # @TODO
    # mentions = get_mentions_from_event(event) ++ Keyword.get(params, :additional_mentions, [])
    mentions = Keyword.get(params, :additional_mentions, [])

    # @TODO
    # content = Kazarma.Matrix.Transaction.build_text_content(event.content, mentions)
    content = Kazarma.Matrix.Transaction.build_text_content(event.content)

    tags = Enum.map(mentions, &mention_tag_for_actor/1)

    case create(
           type: type,
           sender: sender,
           receivers_id: to,
           context: context,
           in_reply_to: in_reply_to,
           content: content,
           attachment: attachment,
           tags: tags
         ) do
      {:ok, %{object: %Object{data: %{"id" => remote_id}}}} ->
        Bridge.create_event(%{
          local_id: event.event_id,
          remote_id: remote_id,
          room_id: event.room_id
        })

      error ->
        {:error, error}
    end
  end

  def create(params) do
    sender = Keyword.fetch!(params, :sender)

    object =
      %{
        "type" => Keyword.fetch!(params, :type),
        "content" => Keyword.fetch!(params, :content),
        "actor" => sender.ap_id,
        "attributedTo" => sender.ap_id,
        "to" => Keyword.fetch!(params, :receivers_id),
        "conversation" => Keyword.get(params, :context)
      }
      |> maybe_put("context", Keyword.get(params, :context))
      |> maybe_put("attachment", Keyword.get(params, :attachment))
      |> maybe_put("tag", Keyword.get(params, :tags))
      |> maybe_put("inReplyTo", Keyword.get(params, :in_reply_to))

    create_params = %{
      actor: Keyword.fetch!(params, :sender),
      context: Keyword.get(params, :context),
      to: Keyword.fetch!(params, :receivers_id),
      object: object
    }

    Logger.ap_output(object)

    {:ok, _activity} = Kazarma.ActivityPub.create(create_params)
  end

  def forward_redaction(%Event{
        room_id: room_id,
        event_id: delete_event_id,
        sender: sender_id,
        type: "m.room.redaction",
        redacts: event_id
      }) do
    Logger.debug("Forwarding deletion")

    with {:ok, actor} <- Kazarma.Address.matrix_id_to_actor(sender_id),
         %BridgeEvent{remote_id: remote_id} <-
           Bridge.get_event_by_local_id(event_id),
         %Object{} = object <- ActivityPub.Object.get_by_ap_id(remote_id),
         {:ok, %{object: %ActivityPub.Object{data: %{"id" => delete_remote_id}}}} <-
           Kazarma.ActivityPub.delete(object, true, actor) do
      Bridge.create_event(%{
        local_id: delete_event_id,
        remote_id: delete_remote_id,
        room_id: room_id
      })

      :ok
    end
  end

  def get_replied_activity_if_exists(%Event{
        content: %{"m.relates_to" => %{"m.in_reply_to" => %{"event_id" => event_id}}}
      }) do
    case Bridge.get_events_by_local_id(event_id) do
      [%BridgeEvent{remote_id: ap_id} | _] ->
        Object.get_cached_by_ap_id(ap_id)

      _ ->
        nil
    end
  end

  def get_replied_activity_if_exists(_), do: nil

  def make_in_reply_to(%Object{data: %{"id" => ap_id}}), do: ap_id
  def make_in_reply_to(%BridgeEvent{remote_id: ap_id}), do: ap_id

  def make_in_reply_to(_), do: nil

  def make_context(%Object{data: %{"context" => context}}, actor), do: context

  def make_context(_, actor), do: ActivityPub.Utils.generate_context_id(actor)

  def mention_tag_for_actor(actor) do
    %{
      "href" => actor.ap_id,
      "name" => "@#{actor.data["preferredUsername"]}",
      "type" => "Mention"
    }
  end

  def attachment_from_matrix_event_content(%{"msgtype" => "m.text"}), do: nil

  def attachment_from_matrix_event_content(%{
        "url" => mxc_url,
        "info" => %{"mimetype" => mimetype}
      }) do
    media_url = Kazarma.Matrix.Client.get_media_url(mxc_url)

    %{
      "mediaType" => mimetype,
      "name" => nil,
      "type" => "Document",
      "url" => [
        %{
          "href" => media_url,
          "mediaType" => mimetype,
          "type" => "Link"
        }
      ]
    }
  end

  def send_message_and_attachment(matrix_id, room_id, object_data, attachments) do
    {text_message, room_id} =
      object_data
      |> make_text_message()
      |> add_reply(object_data, room_id)

    message_result =
      text_message &&
        Kazarma.Matrix.Client.send_tagged_message(
          room_id,
          matrix_id,
          text_message
        )

    attachments_results = send_attachments(matrix_id, room_id, attachments)

    get_result([message_result | attachments_results])
  end

  defp send_attachments(from, room_id, [nil | rest]), do: send_attachments(from, room_id, rest)

  defp send_attachments(from, room_id, [attachment | rest]) do
    result =
      normalize_attachment(attachment)
      |> Client.send_attachment_message_for_ap_data(from, room_id)

    [result | send_attachments(from, room_id, rest)]
  end

  defp send_attachments(_from, _room_id, _), do: []

  defp normalize_attachment(%{"mediaType" => mimetype, "url" => [%{"href" => url} | _]}) do
    %{mimetype: mimetype, url: url}
  end

  defp normalize_attachment(%{"mediaType" => mediatype, "url" => url}) do
    %{mimetype: mediatype, url: url}
  end

  defp make_text_message(%{"source" => nil, "content" => nil}), do: nil
  defp make_text_message(%{"source" => "", "content" => ""}), do: nil

  defp make_text_message(%{"source" => source, "content" => content} = data) do
    tags = Map.get(data, "tag")
    body = process_message_text(source, tags)
    formatted_body = process_message_html(content, tags)

    {body, formatted_body}
  end

  defp make_text_message(%{"source" => nil}), do: nil
  defp make_text_message(%{"source" => ""}), do: nil

  defp make_text_message(%{"source" => source}) do
    source
  end

  defp make_text_message(%{"content" => nil}), do: nil
  defp make_text_message(%{"content" => ""}), do: nil

  defp make_text_message(%{"content" => content} = data) do
    tags = Map.get(data, "tag")
    body = process_message_text(content, tags)
    formatted_body = process_message_html(content, tags)

    {body, formatted_body}
  end

  defp process_message_text(content, tags) do
    content
    |> strip_tags()
    |> convert_mentions_text_to_text(tags)
  end

  defp process_message_html(content, tags) do
    content
    |> convert_mentions_html(tags)
    |> convert_mentions_text_to_html(tags)
    |> scrub()
  end

  defp scrub(content) do
    HtmlSanitizeEx.Scrubber.scrub(content, Kazarma.Matrix.Scrubber)
  end

  defp strip_tags(content) do
    HtmlSanitizeEx.strip_tags(content)
  end

  defp add_reply(body, object_data, room_id) when is_binary(body),
    do: add_reply({body, body}, object_data, room_id)

  defp add_reply({body, formatted_body}, %{"inReplyTo" => reply_to_ap_id}, room_id)
       when not is_nil(reply_to_ap_id) do
    case Bridge.get_events_by_remote_id(reply_to_ap_id) do
      [%BridgeEvent{local_id: event_id, room_id: replied_to_room_id} | _] ->
        {Client.reply_event(event_id, body, formatted_body), replied_to_room_id}

      _ ->
        {{body, formatted_body}, room_id}
    end
  end

  defp add_reply(text_message, _, room_id), do: {text_message, room_id}

  defp convert_mentions_html(content, tags) do
    convert_mentions(content, tags, fn current_content, actor, ap_id, username, matrix_id ->
      display_name = actor.data["name"]
      "@" <> username_without_at = username

      parse_and_update_content(
        current_content,
        username_without_at,
        ap_id,
        matrix_id,
        display_name
      )
    end)
  end

  defp convert_mentions_text_to_html(content, tags) do
    convert_mentions(content, tags, fn current_content, actor, _ap_id, username, matrix_id ->
      String.replace(
        current_content,
        username,
        Address.matrix_mention_tag(matrix_id, actor.data["name"])
      )
    end)
  end

  defp convert_mentions_text_to_text(content, tags) do
    convert_mentions(content, tags, fn current_content, _actor, _ap_id, username, matrix_id ->
      String.replace(current_content, username, matrix_id)
    end)
  end

  defp convert_mentions(content, nil, _), do: content

  # @TODO stop using tags since Mobilizon does mentions without tags
  defp convert_mentions(content, tags, convert_fun) do
    Enum.reduce(tags, content, fn
      %{"type" => "Mention", "href" => ap_id, "name" => username}, content ->
        with {:ok, actor} <- ActivityPub.Actor.get_cached_by_ap_id(ap_id),
             {:ok, matrix_id} <- Address.ap_username_to_matrix_id(actor.username) do
          convert_fun.(content, actor, ap_id, username, matrix_id)
        else
          _ -> content
        end

      _, content ->
        content
    end)
  end

  defp parse_and_update_content(content, username_without_at, ap_id, matrix_id, display_name) do
    update_fun = fn
      {"span", span_attrs, [{"a", a_attrs, ["@", {"span", _, [^username_without_at]}]}]} = elem ->
        if {"class", "h-card"} in span_attrs && {"href", ap_id} in a_attrs &&
             {"class", "u-url mention"} in a_attrs do
          {"a", [{"href", "https://matrix.to/#/" <> matrix_id}], [display_name]}
        else
          elem
        end

      other ->
        other
    end

    case Floki.parse_document(content) do
      {:ok, html} ->
        html
        |> Floki.traverse_and_update(update_fun)
        |> Floki.raw_html()

      _ ->
        content
    end
  end

  def get_replies_for(%{data: %{"id" => ap_id}}, offset \\ 0, limit \\ 10) do
    from(object in ActivityPub.Object,
      where: fragment("(?)->>'inReplyTo' = ?", object.data, ^ap_id),
      where: fragment("(?)->>'type' = ?", object.data, ^"Note"),
      where:
        fragment("(?)->'to' \\? ?", object.data, ^"https://www.w3.org/ns/activitystreams#Public"),
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: object.inserted_at]
    )
    |> Kazarma.Repo.all()
  end

  defp get_result([{:error, error} | _rest]), do: {:error, error}
  defp get_result([{:ok, value} | _rest]), do: {:ok, value}
  defp get_result([_anything_else | rest]), do: get_result(rest)
  defp get_result([]), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
