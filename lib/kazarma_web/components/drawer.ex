# SPDX-FileCopyrightText: 2020-2024 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Components.Drawer do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML

  slot(:page, required: true)
  slot(:sidebar, required: true)
  slot(:button, required: true)

  def drawer(assigns) do
    ~H"""
    <div class="drawer drawer-mobile h-auto lg:grid-cols-3 overflow-visible">
      <input id="actor-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content lg:col-span-2">
        <label
          for="actor-drawer"
          class="btn btn-secondary btn-block rounded-none drawer-button lg:hidden normal-case"
        >
          <%= render_slot(@button) %>
        </label>
        <%= render_slot(@page) %>
      </div>
      <div class="drawer-side max-h-unset overflow-y-unset min-h-[calc(100vh_-_8rem)] sm:min-h-[calc(100vh_-_4rem)]">
        <label for="actor-drawer" class="drawer-overlay"></label>
        <div class="menu p-4 w-80 lg:w-[33vw] bg-base-100 text-base-content">
          <div class="container mx-auto flex flex-col lg:max-w-3xl px-4 sticky h-full justify-between">
            <%= render_slot(@sidebar) %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
