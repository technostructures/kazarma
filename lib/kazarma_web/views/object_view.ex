# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ObjectView do
  use KazarmaWeb, :view

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
end
