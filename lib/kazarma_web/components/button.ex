defmodule KazarmaWeb.Button do
  use Phoenix.Component
  import KazarmaWeb.Gettext
  use Phoenix.HTML

  def copy(assigns) do
    ~H"""
    <button aria-label={gettext("Copy")} title={gettext("Copy")} data-copy-id={@copy_id} class="btn btn-copy btn-primary">
      <%= KazarmaWeb.IconView.copy_icon() %>
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
end
