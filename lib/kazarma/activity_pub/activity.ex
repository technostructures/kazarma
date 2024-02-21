# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ActivityPub.Activity do
  @moduledoc """
  Activity-related functions.
  """
  alias ActivityPub.Object
  alias Kazarma.Address
  alias Kazarma.Bridge
  alias MatrixAppService.Bridge.Event, as: BridgeEvent
  alias Kazarma.Matrix.Client
  alias MatrixAppService.Event
  alias MatrixAppService.Bridge.Room

  import Ecto.Query

  def create_from_event(
        event,
        params
      ) do
    sender = Keyword.fetch!(params, :sender)

    replied_activity =
      get_replied_activity_if_exists(event) || Keyword.get(params, :fallback_reply)

    manual_mentions = Kazarma.Matrix.Transaction.get_mentions_from_event_content(event.content)

    additional_mentions = Keyword.get(params, :additional_mentions, [])

    tags = Enum.map(manual_mentions ++ additional_mentions, &mention_tag_for_actor/1)

    case create(
           type: Keyword.get(params, :type, "Note"),
           sender: sender,
           to: Keyword.fetch!(params, :to),
           cc: Keyword.get(params, :cc, []),
           context: Keyword.get(params, :context, make_context(replied_activity, sender)),
           in_reply_to: make_in_reply_to(replied_activity),
           content:
             Kazarma.Matrix.Transaction.build_text_content(event.content, additional_mentions),
           attachment: attachment_from_matrix_event_content(event.content),
           tags: tags,
           name: Keyword.get(params, :name),
           attributed_to: Keyword.get(params, :attributed_to, sender.ap_id)
         ) do
      {:ok, %{object: %Object{data: %{"id" => remote_id}}} = activity} ->
        Bridge.create_event(%{
          local_id: event.event_id,
          remote_id: remote_id,
          room_id: event.room_id
        })

        {:ok, activity}

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
        "attributedTo" => Keyword.fetch!(params, :attributed_to),
        "to" => Keyword.fetch!(params, :to),
        "cc" => Keyword.get(params, :cc, []),
        "conversation" => Keyword.get(params, :context),
        "tag" => Keyword.get(params, :tags, [])
      }
      |> maybe_put("context", Keyword.get(params, :context))
      |> maybe_put("attachment", Keyword.get(params, :attachment))
      |> maybe_put("tag", Keyword.get(params, :tags))
      |> maybe_put("inReplyTo", Keyword.get(params, :in_reply_to))
      |> maybe_put("name", Keyword.get(params, :name))

    create_params = %{
      actor: Keyword.fetch!(params, :sender),
      context: Keyword.get(params, :context),
      to: Keyword.fetch!(params, :to),
      object: object,
      additional: %{"cc" => Keyword.get(params, :cc, [])}
    }

    {:ok, _activity} = Kazarma.ActivityPub.create(create_params)
  end

  def forward_redaction(
        %Event{
          room_id: room_id,
          event_id: delete_event_id,
          sender: sender_id,
          type: "m.room.redaction",
          redacts: event_id
        } = event
      ) do
    {:ok, actor} = Kazarma.Address.matrix_id_to_actor(sender_id)

    for %BridgeEvent{remote_id: remote_id} <- Bridge.get_events_by_local_id(event_id) do
      {:ok, %Object{} = object} = ActivityPub.Object.get_cached(ap_id: remote_id)

      {:ok, %{object: %ActivityPub.Object{data: %{"id" => delete_remote_id}}}} =
        Kazarma.ActivityPub.delete(object, true, actor)

      Bridge.create_event(%{
        local_id: delete_event_id,
        remote_id: delete_remote_id,
        room_id: room_id
      })

      %Room{data: %{"type" => room_type}} = Bridge.get_room_by_local_id(room_id)

      Kazarma.Logger.log_bridged_event(event,
        room_type: room_type
      )
    end

    :ok
  end

  def get_replied_activity_if_exists(%Event{
        content: %{"m.relates_to" => %{"m.in_reply_to" => %{"event_id" => event_id}}}
      }) do
    case Bridge.get_events_by_local_id(event_id) do
      [%BridgeEvent{remote_id: ap_id} | _] ->
        {:ok, activity} = Object.get_cached(ap_id: ap_id)
        activity

      _ ->
        nil
    end
  end

  def get_replied_activity_if_exists(_), do: nil

  def make_in_reply_to(%Object{data: %{"id" => ap_id}}), do: ap_id
  def make_in_reply_to(%BridgeEvent{remote_id: ap_id}), do: ap_id

  def make_in_reply_to(_), do: nil

  def make_context(%Object{data: %{"context" => context}}, _actor), do: context

  def make_context(_, actor), do: ActivityPub.Utils.generate_context_id(actor)

  def mention_tag_for_actor(actor) do
    %{
      "href" => actor.ap_id,
      "name" => "@#{mention_name(actor)}",
      "type" => "Mention"
    }
  end

  def mention_name(%{local: true, data: %{"preferredUsername" => name}}), do: name
  def mention_name(%{local: false, username: name}), do: name

  def attachment_from_matrix_event_content(%{"msgtype" => "m.text"}), do: nil

  def attachment_from_matrix_event_content(%{
        "url" => mxc_url,
        "info" => %{"mimetype" => mimetype}
      }) do
    media_url = Kazarma.Matrix.Client.get_media_url(mxc_url)

    %{
      "mediaType" => mimetype,
      "name" => "",
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

  def send_message_and_attachment(
        matrix_id,
        room_id,
        %{"id" => object_id} = object_data,
        attachments
      ) do
    {content, room_id} =
      object_data
      |> make_content()
      |> add_reply(object_data, room_id)

    content = add_attachments(matrix_id, content, attachments)

    case content &&
           Kazarma.Matrix.Client.send_tagged_message(
             room_id,
             matrix_id,
             content
           ) do
      {:ok, event_id} ->
        {:ok, _} =
          Bridge.create_event(%{
            local_id: event_id,
            remote_id: object_id,
            room_id: room_id
          })

        Kazarma.Logger.log_bridged_event(
          %MatrixAppService.Event{
            event_id: event_id,
            type: "m.room.message",
            room_id: room_id,
            sender: matrix_id,
            user_id: matrix_id,
            content: content,
            state_key: nil
          },
          room_type: :collection,
          obj_type: "Note"
        )

        :ok

      _ ->
        :error
    end
  end

  defp add_attachments(_matrix_id, content, nil), do: content
  defp add_attachments(_matrix_id, content, []), do: content
  defp add_attachments(_matrix_id, content, [nil]), do: content

  defp add_attachments(matrix_id, nil, attachments) do
    add_attachments(matrix_id, "", attachments)
  end

  defp add_attachments(matrix_id, content, [attachment | rest]) when is_binary(content) do
    add_attachments(
      matrix_id,
      %{
        "msgtype" => "m.text",
        "body" => content,
        "formatted_body" => content,
        "format" => "org.matrix.custom.html"
      },
      [attachment | rest]
    )
  end

  defp add_attachments(
         matrix_id,
         %{"body" => body} = content,
         [attachment | rest]
       )
       when not is_nil(attachment) do
    {:ok, matrix_url} = Client.upload_media(matrix_id, attachment_url(attachment))

    formatted_body = Map.get(content, "formatted_body", body)

    formatted_body =
      formatted_body <>
        add_new_formatted_line(formatted_body) <>
        formatted_body_for_attachment(matrix_url, attachment)

    body = body <> add_new_line(body) <> matrix_url

    content = %{content | "body" => body, "formatted_body" => formatted_body}

    add_attachments(matrix_id, content, rest)
  end

  defp add_new_line(""), do: ""
  defp add_new_line(_), do: "\n"

  defp add_new_formatted_line(""), do: ""
  defp add_new_formatted_line(_), do: "<br>"

  defp formatted_body_for_attachment(url, %{"mediaType" => "image/" <> _} = attachment) do
    ~s(<img src="#{url}" title="#{attachment_title(attachment)}">)
  end

  defp formatted_body_for_attachment(url, %{"mediaType" => "audio/" <> _} = attachment) do
    url = Client.get_media_url(url)

    ~s(<audio src="#{url}" title="#{attachment_title(attachment)}"><a href="#{url}">#{attachment_title(attachment)}</a></audio>)
  end

  defp formatted_body_for_attachment(url, attachment) do
    url = Client.get_media_url(url)

    ~s(<a href="#{url}">#{attachment_title(attachment)}</a>)
  end

  defp attachment_url(%{"url" => [%{"href" => url} | _]}), do: url
  defp attachment_url(%{"url" => url}), do: url

  defp attachment_title(%{"name" => name}) when name not in [nil, ""], do: name
  defp attachment_title(_), do: "Attachment"

  # Lemmy post
  defp make_content(%{
         "name" => title,
         "source" => %{"content" => source},
         "content" => content,
         "attachment" => [%{"type" => "Link", "url" => [%{"href" => href}]}]
       }) do
    source = "#{title}\n#{href}\n\n#{source}"
    content = "<a href=\"#{href}\"><h3>#{title}</h3></a>#{content}"
    make_content(%{"source" => source, "content" => content})
  end

  defp make_content(%{
         "name" => title,
         "attachment" => [%{"type" => "Link", "url" => [%{"href" => href}]}]
       }) do
    source = "#{title}\n#{href}"
    content = "<a href=\"#{href}\"><h3>#{title}</h3></a>"
    make_content(%{"source" => source, "content" => content})
  end

  defp make_content(%{"name" => title, "source" => %{"content" => source}, "content" => content}) do
    source = "#{title}\n\n#{source}"
    content = "<h3>#{title}</h3>#{content}"
    make_content(%{"source" => source, "content" => content})
  end

  defp make_content(%{"source" => %{"content" => source}, "content" => content}) do
    make_content(%{"source" => source, "content" => content})
  end

  defp make_content(%{"source" => nil, "content" => nil}), do: nil
  defp make_content(%{"source" => "", "content" => ""}), do: nil

  defp make_content(%{"source" => source, "content" => content} = data) do
    tags = Map.get(data, "tag")
    body = process_message_text(source, tags)
    formatted_body = process_message_html(content, tags)

    %{
      "msgtype" => "m.text",
      "body" => body,
      "formatted_body" => formatted_body,
      "format" => "org.matrix.custom.html"
    }
  end

  defp make_content(%{"source" => nil}), do: nil
  defp make_content(%{"source" => ""}), do: nil

  defp make_content(%{"source" => source}), do: source

  defp make_content(%{"content" => nil}), do: nil
  defp make_content(%{"content" => ""}), do: nil

  defp make_content(%{"content" => content} = data) do
    tags = Map.get(data, "tag")
    body = process_message_text(content, tags)
    formatted_body = process_message_html(content, tags)

    %{
      "msgtype" => "m.text",
      "body" => body,
      "formatted_body" => formatted_body,
      "format" => "org.matrix.custom.html"
    }
  end

  defp make_content(object_data) do
    dbg(object_data)
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

  defp add_reply(content, %{"inReplyTo" => reply_to_ap_id}, room_id)
       when not is_nil(reply_to_ap_id) do
    case Bridge.get_events_by_remote_id(reply_to_ap_id) do
      [%BridgeEvent{local_id: event_id, room_id: replied_to_room_id} | _] ->
        {Client.reply_event(event_id, content), replied_to_room_id}

      _ ->
        {content, room_id}
    end
  end

  defp add_reply(content, _, room_id), do: {content, room_id}

  defp convert_mentions_html(content, tags) do
    convert_mentions(content, tags, fn current_content, actor, ap_id, username, matrix_id ->
      display_name = actor.data["name"]
      "@" <> username_without_at = username

      parse_and_update_content(
        current_content,
        username_without_at,
        ap_id,
        {"a", [{"href", "https://matrix.to/#/" <> matrix_id}], [display_name]}
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

  def convert_mentions(content, nil, _), do: content

  # @TODO stop using tags since Mobilizon does mentions without tags
  def convert_mentions(content, tags, convert_fun) do
    Enum.reduce(tags, content, fn
      %{"type" => "Mention", "href" => ap_id, "name" => username}, content ->
        with {:ok, actor} <- ActivityPub.Actor.get_cached(ap_id: ap_id),
             {:ok, matrix_id} <- Address.ap_username_to_matrix_id(actor.username) do
          convert_fun.(content, actor, ap_id, username, matrix_id)
        else
          _ -> content
        end

      _, content ->
        content
    end)
  end

  def parse_and_update_content(content, username_without_at, ap_id, replacement) do
    update_fun = fn
      {"span", span_attrs, [{"a", a_attrs, ["@", {"span", _, [_username_without_at]}]}]} = elem ->
        if {"class", "h-card"} in span_attrs && {"href", ap_id} in a_attrs &&
             {"class", "u-url mention"} in a_attrs do
          replacement
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
