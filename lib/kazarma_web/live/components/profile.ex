# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.Profile do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.Helpers
  import KazarmaWeb.Gettext

  defp avatar(assigns) do
    ~H"""
    <div>
      <div class="avatar" :if={!is_nil(avatar_url(@actor))}>
        <div class="rounded-full w-12 h-12 shadow">
          <img src={avatar_url(@actor)} alt={gettext("%{actor_name}'s avatar", actor_name: @actor.data["name"])}>
        </div>
      </div>
    </div>
    """
  end

  defp name(assigns) do
    ~H"""
      <div class="">
        <h1 class="card-title text-2xl">
          <%= display_name(@actor) %>
        </h1>
      </div>
    """
  end

  defp type_badge(assigns) do
    ~H"""
      <div class="">
        <div class="badge badge-lg">
          <%= type(@actor) %>
        </div>
      </div>
    """
  end

  def original_profile(assigns) do
    ~H"""
      <div class="flex flex-row items-center space-x-4">
        <.avatar actor={@actor} />
        <.name actor={@actor} />
        <.type_badge actor={@actor} />
      </div>
    """
  end

  slot(:buttons, required: true)

  def row(assigns) do
    ~H"""
    <div class="form-control">
      <label for={@id} class="label">
        <span class="label-text"><%= @label %></span>
      </label> 
      <div class="flex flex-wrap gap-2 content-center">
        <input type="text" id={@id} aria-label={@label} class="flex-grow input input-bordered border-opacity-80" value={@value} readonly="readonly">
        <KazarmaWeb.Button.copy copy_id={@id} />
        <%= render_slot(@buttons) %>
      </div>
    </div>
    """
  end

  def matrix_rows(assigns) do
    ~H"""
      <div class="card card-body bg-base-300 base-100 mt-10">
        <h2 class="text-2xl text-center">Matrix</h2>
        <.row id="matrix-username" label={gettext("Username")} value={matrix_username(@actor)}>
          <:buttons>
            <KazarmaWeb.Button.secondary to={"https://matrix.to/#/" <> matrix_username(@actor)} link_text="matrix.to" />
            <KazarmaWeb.Button.secondary to={matrix_scheme_user(@actor)} link_text="matrix:" />
          </:buttons>
        </.row>
        <.row id="matrix-outbox-room" label={gettext("Outbox room")} value={matrix_outbox_room(@actor)}>
          <:buttons>
            <KazarmaWeb.Button.secondary to={"https://matrix.to/#/" <> matrix_outbox_room(@actor)} link_text="matrix.to" />
            <KazarmaWeb.Button.secondary to={matrix_scheme_room(@actor)} link_text="matrix:" />
          </:buttons>
        </.row>
      </div>
    """
  end

  def ap_rows(assigns) do
    ~H"""
      <div class="card card-body bg-base-300 base-100 mt-10">
        <h2 class="text-2xl text-center pt-5">ActivityPub</h2>
        <div class="flex flex-col space-y-2">
          <.row id="activitypub-id" label={gettext("ActivityPub ID")} value={ap_id(@actor)}>
            <:buttons>
              <%= link [to: ap_id(@actor), target: "_blank", aria_label: gettext("Open"), title: gettext("Open"), class: "btn btn-secondary"], do: KazarmaWeb.IconView.external_link_icon() %>
            </:buttons>
          </.row>
          <.row id="activitypub-username" label={gettext("ActivityPub username")} value={ap_username(@actor)}>
            <:buttons></:buttons>
          </.row>
        </div>
      </div>
    """
  end

  def puppet_profile(%{actor: %ActivityPub.Actor{local: true}} = assigns) do
    ~H"""
    <.matrix_rows actor={@actor} />
    <.ap_rows actor={@actor} />
    """
  end

  def puppet_profile(%{actor: %ActivityPub.Actor{data: %{"type" => _type}}} = assigns) do
    ~H"""
    <.ap_rows actor={@actor} />
    <.matrix_rows actor={@actor} />
    """
  end

  def show(assigns) do
    ~H"""
    <div class="container mx-auto flex flex-col lg:max-w-3xl px-4">
      <.original_profile actor={@actor} />
      <div class="divider"></div> 
      <.puppet_profile actor={@actor} />
    </div>
    """
  end
end
