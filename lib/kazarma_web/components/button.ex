# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Button do
  @moduledoc false
  use KazarmaWeb, :html
  import KazarmaWeb.Components.Icon

  def copy(assigns) do
    ~H"""
    <button
      aria-label={gettext("Copy")}
      title={gettext("Copy")}
      data-copy-id={@copy_id}
      class="btn btn-copy btn-primary"
    >
      <.copy_icon />
    </button>
    """
  end

  def secondary(assigns) do
    ~H"""
    <%= link [to: @to, target: "_blank", class: "btn btn-secondary"] do %>
      <%= @link_text %>
    <% end %>
    """
  end

  def ghost(assigns) do
    ~H"""
    <%= link [to: @to, target: "_blank", class: "btn btn-ghost btn-sm lowercase"] do %>
      <%= @link_text %>
    <% end %>
    """
  end
end
