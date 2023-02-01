# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.Profile do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.Components.Icon
  import KazarmaWeb.Helpers
  import KazarmaWeb.Gettext

  defp profile_address(%{actor: %ActivityPub.Actor{local: true}} = assigns) do
    ~H"""
    <.address_that_opens to={matrix_to(@actor)} address={matrix_id(@actor)} />
    """
  end

  defp profile_address(%{actor: %ActivityPub.Actor{}} = assigns) do
    ~H"""
    <.address_that_opens to={url(@actor)} address={ap_username(@actor)} />
    """
  end

  defp puppet_addresses(%{actor: %ActivityPub.Actor{local: true}} = assigns) do
    ~H"""
    <.address_that_copies to={url(@actor)} address={ap_username(@actor)} />
    """
  end

  defp puppet_addresses(%{actor: %ActivityPub.Actor{}} = assigns) do
    assigns = assign(assigns, :outbox_room, outbox_room(assigns.actor))

    ~H"""
    <.address_that_opens to={matrix_to(@actor)} address={matrix_id(@actor)} />
    <.address_that_opens
      :if={@outbox_room}
      to={"https://matrix.to/#/" <> @outbox_room}
      address={@outbox_room}
    />
    """
  end

  defp address_that_opens(assigns) do
    ~H"""
    <div class="tooltip" data-tip="Click to open">
      <.link href={@to} target="_blank" aria-label={gettext("Open")} class="link link-hover">
        <%= @address %>
      </.link>
    </div>
    """
  end

  defp address_that_copies(assigns) do
    ~H"""
    <div class="tooltip" data-tip="Click to copy">
      <.link href="#" aria-label={gettext("Copy")} data-copy={@address} class="link link-hover">
        <%= @address %>
      </.link>
    </div>
    """
  end

  def original_profile(assigns) do
    ~H"""
    <div class="card shadow-lg bg-base-100 flex flex-row base-100">
      <div :if={!is_nil(avatar_url(@actor))} class="avatar">
        <div class="rounded-full w-24 h-24 my-4 ml-4 shadow">
          <.link
            navigate={Kazarma.ActivityPub.Adapter.actor_path(@actor)}
            class="link link-hover"
            title={main_address(@actor)}
          >
            <img
              src={avatar_url(@actor)}
              alt={gettext("%{actor_name}'s avatar", actor_name: @actor.data["name"])}
            />
          </.link>
        </div>
      </div>
      <div class="card-body p-6">
        <div class="card-title flex flex-row flex-wrap">
          <h1 class="grow text-2xl">
            <.link
              navigate={Kazarma.ActivityPub.Adapter.actor_path(@actor)}
              class="link link-hover"
              title={main_address(@actor)}
            >
              <%= display_name(@actor) %>
            </.link>
          </h1>
          <div class="grow-0">
            <%= type_icon(@actor) %>
          </div>
        </div>
        <div>
          <.profile_address actor={@actor} />
        </div>
      </div>
    </div>
    """
  end

  def puppet_profile(assigns) do
    ~H"""
    <div class="card shadow-lg bg-base-300 base-100 mt-4">
      <div class="card-body p-6">
        <div class="flex flex-row">
          <div class="mr-2"><%= opposite_type_icon(@actor) %></div>
          via Kazarma
        </div>
        <div class="">
          <.puppet_addresses actor={@actor} />
        </div>
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
