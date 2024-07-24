# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ErrorHTMLTest do
  use KazarmaWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(KazarmaWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(KazarmaWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
