# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Matrix.Scrubber do
  @moduledoc """
  Sanitizer for Matrix event.

  https://spec.matrix.org/v1.4/client-server-api/#mroommessage-msgtypes
  """

  require HtmlSanitizeEx.Scrubber.Meta
  alias HtmlSanitizeEx.Scrubber.Meta

  Meta.remove_cdata_sections_before_scrub()
  Meta.strip_comments()

  # @TODO:
  # Where data-mx-bg-color and data-mx-color are listed, clients should translate the value (a 6-character hex color code) to the appropriate CSS/attributes for the tag.
  # Additionally, web clients should ensure that all a tags get a rel="noopener" to prevent the target page from referencing the client’s tab/window.

  Meta.allow_tag_with_these_attributes("font", ["data-mx-bg-color", "data-mx-color", "color"])

  Meta.allow_tag_with_these_attributes("span", [
    "data-mx-bg-color",
    "data-mx-color",
    "data-mx-spoiler"
  ])

  Meta.allow_tag_with_these_attributes("a", [])

  Meta.allow_tag_with_uri_attributes("a", ["name", "target", "href"], [
    "https",
    "http",
    "ftp",
    "mailto",
    "magnet"
  ])

  Meta.allow_tag_with_these_attributes("img", ["width", "height", "alt", "title", "src"])
  Meta.allow_tag_with_these_attributes("ol", ["start"])
  Meta.allow_tag_with_these_attributes("code", ["class"])
  Meta.allow_tag_with_these_attributes("h1", [])
  Meta.allow_tag_with_these_attributes("h2", [])
  Meta.allow_tag_with_these_attributes("h3", [])
  Meta.allow_tag_with_these_attributes("h4", [])
  Meta.allow_tag_with_these_attributes("h5", [])
  Meta.allow_tag_with_these_attributes("h6", [])
  Meta.allow_tag_with_these_attributes("blockquote", [])
  Meta.allow_tag_with_these_attributes("p", [])
  Meta.allow_tag_with_these_attributes("ul", [])
  Meta.allow_tag_with_these_attributes("sup", [])
  Meta.allow_tag_with_these_attributes("sub", [])
  Meta.allow_tag_with_these_attributes("li", [])
  Meta.allow_tag_with_these_attributes("b", [])
  Meta.allow_tag_with_these_attributes("i", [])
  Meta.allow_tag_with_these_attributes("u", [])
  Meta.allow_tag_with_these_attributes("strong", [])
  Meta.allow_tag_with_these_attributes("em", [])
  Meta.allow_tag_with_these_attributes("strike", [])
  Meta.allow_tag_with_these_attributes("hr", [])
  Meta.allow_tag_with_these_attributes("br", [])
  Meta.allow_tag_with_these_attributes("div", [])
  Meta.allow_tag_with_these_attributes("table", [])
  Meta.allow_tag_with_these_attributes("thead", [])
  Meta.allow_tag_with_these_attributes("tbody", [])
  Meta.allow_tag_with_these_attributes("tr", [])
  Meta.allow_tag_with_these_attributes("th", [])
  Meta.allow_tag_with_these_attributes("td", [])
  Meta.allow_tag_with_these_attributes("caption", [])
  Meta.allow_tag_with_these_attributes("pre", [])
  Meta.allow_tag_with_these_attributes("del", [])
  Meta.allow_tag_with_these_attributes("details", [])
  Meta.allow_tag_with_these_attributes("summary", [])

  Meta.strip_everything_not_covered()
end
