# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.Profile do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.Components.Icon
  import KazarmaWeb.Helpers
  import KazarmaWeb.Gettext

  defp avatar(assigns) do
    ~H"""
    <div>
      <div :if={!is_nil(avatar_url(@actor))} class="avatar">
        <div class="rounded-full w-12 h-12 shadow">
          <img
            src={avatar_url(@actor)}
            alt={gettext("%{actor_name}'s avatar", actor_name: @actor.data["name"])}
          />
        </div>
      </div>
    </div>
    """
  end

  defp type_prefix(assigns) do
    ~H"""
    <span>
      <%= type(@actor) %>:
    </span>
    """
  end

  defp type_badge(assigns) do
    ~H"""
    <div class="badge h-auto">
      <%= type(@actor) %>
    </div>
    """
  end

  defp puppet_type_badge(assigns) do
    ~H"""
    <div class="badge h-auto">
      <%= puppet_type(@actor) %>
    </div>
    """
  end

  defp external_link(assigns) do
    ~H"""
    <%= link [
        to: @to,
        target: "_blank",
        aria_label: gettext("Open"),
        title: gettext("Open"),
        class: "btn btn-ghost btn-sm"
      ] do %>
      <.external_link_icon />
    <% end %>
    """
  end

  defp matrix_links(assigns) do
    ~H"""
    <.external_link to={"https://matrix.to/#/" <> matrix_id(@actor)} />
    <KazarmaWeb.Button.ghost to={matrix_scheme_user(@actor)} link_text="[m]" />
    """
  end

  defp ap_links(assigns) do
    ~H"""
    <.external_link to={ap_id(@actor)} />
    """
  end

  defp profile_links(%{actor: %ActivityPub.Actor{local: true}} = assigns),
    do: matrix_links(assigns)

  defp profile_links(%{actor: %ActivityPub.Actor{data: %{"type" => _type}}} = assigns),
    do: ap_links(assigns)

  defp puppet_profile_links(%{actor: %ActivityPub.Actor{local: true}} = assigns), do: ~H()

  defp puppet_profile_links(%{actor: %ActivityPub.Actor{data: %{"type" => _type}}} = assigns),
    do: matrix_links(assigns)

  defp address_and_link(assigns) do
    ~H"""
    <div class="flex space-x-6">
      <%= link [
        to: "#",
        aria_label: gettext("Copy"),
      title: gettext("Copy"),
      data: [copy: @address],
      class: "link link-secondary link-hover link-neutral font-mono overflow-x-auto"
    ]
    do %>
        <%= @address %>
      <% end %>
      <%= link [
        to: "#",
        aria_label: gettext("Copy"),
      title: gettext("Copy"),
      data: [copy: @address],
      class: "link link-secondary link-hover link-neutral font-mono"
    ]
    do %>
        <.copy_icon />
      <% end %>
    </div>
    """
  end

  defp main_address(%{actor: %ActivityPub.Actor{local: true}} = assigns) do
    ~H"""
    <.address_and_link address={matrix_id(@actor)} />
    """
  end

  defp main_address(%{actor: %ActivityPub.Actor{data: %{"type" => _type}}} = assigns) do
    ~H"""
    <.address_and_link address={ap_username(@actor)} />
    """
  end

  defp puppet_address(%{actor: %ActivityPub.Actor{local: true}} = assigns) do
    ~H"""
    <.address_and_link address={ap_username(@actor)} />
    """
  end

  defp puppet_address(%{actor: %ActivityPub.Actor{data: %{"type" => _type}}} = assigns) do
    ~H"""
    <.address_and_link address={matrix_id(@actor)} />
    """
  end

  def original_profile(assigns) do
    ~H"""
    <div class="card shadow-lg bg-base-100 base-100">
      <div class="card-body p-6">
        <h1 class="card-title flex-wrap text-2xl">
          <%= display_name(@actor) %>
          <.profile_links actor={@actor} />
          <.type_badge actor={@actor} />
        </h1>
        <div>
          <.avatar actor={@actor} />
        </div>
        <div>
          <!-- <.type_prefix actor={@actor} /> -->
          <.main_address actor={@actor} />
        </div>
      </div>
    </div>
    """
  end

  def puppet_profile(assigns) do
    ~H"""
    <div class="card shadow-lg bg-base-300 base-100 mt-4">
      <div class="card-body p-6">
        <h2 class="card-title flex-wrap">
          <%= display_name(@actor) %>
          <.puppet_profile_links actor={@actor} />
          <.puppet_type_badge actor={@actor} />
        </h2>
        <.puppet_address actor={@actor} />
        <!-- <KazarmaWeb.Button.secondary to={"https://matrix.to/#/" <> matrix_outbox_room(@actor)} link_text="matrix.to" /> -->
        <!-- <KazarmaWeb.Button.secondary to={matrix_scheme_room(@actor)} link_text="matrix:" /> -->
      </div>
    </div>
    """
  end

  def show(assigns) do
    ~H"""
    <.original_profile actor={@actor} />
    <!-- <div class="divider"></div> -->
    <.puppet_profile actor={@actor} />
    """
  end
end
