# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ErrorViewTest do
  use KazarmaWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.json" do
    assert render(KazarmaWeb.ErrorJSON, "404.json", []) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500.json" do
    assert render(KazarmaWeb.ErrorJSON, "500.json", []) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
