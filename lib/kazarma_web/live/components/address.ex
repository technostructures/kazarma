# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Address do
  @moduledoc false
  use Phoenix.Component
  import KazarmaWeb.Gettext
  use Phoenix.HTML

  slot(:buttons, required: true)

  def row(assigns) do
    ~H"""
    <div class="form-control">
      <label for={@id} class="label">
        <span class="label-text"><%= @label %></span>
      </label>
      <div class="flex flex-wrap gap-2 content-center">
        <input
          type="text"
          id={@id}
          aria-label={@label}
          class="flex-grow input input-bordered border-opacity-80"
          value={@value}
          readonly="readonly"
        />
        <KazarmaWeb.Button.copy copy_id={@id} />
        <%= render_slot(@buttons) %>
      </div>
    </div>
    """
  end
end
