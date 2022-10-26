# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Actor do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.ActorView
  import KazarmaWeb.Gettext

  def header(assigns) do
    ~H"""
      <div class="flex flex-row items-center space-x-4">
        <div>
          <%= unless is_nil(avatar_url(@actor)) do %>
            <div class="avatar">
              <div class="rounded-full w-12 h-12 shadow">
                <img src={avatar_url(@actor)} alt={gettext("%{actor_name}'s avatar", actor_name: @actor.data["name"])}>
              </div>
            </div>
          <% end %>
        </div>
        <div class="">
          <h1 class="card-title text-xl">
            <%= display_name(@actor) %>
          </h1>
        </div>
        <div class="">
          <div class="badge badge-lg">
            <%= type(@actor) %>
          </div>
        </div>
      </div>
    """
  end

  def matrix_rows(assigns) do
    ~H"""
      <div class="card card-body bg-base-300 base-100 mt-10">
        <h2 class="text-2xl text-center">Matrix</h2>
        <KazarmaWeb.Address.row id="matrix-username" label={gettext("Username")} value={matrix_username(@actor)}>
          <:buttons>
            <KazarmaWeb.Button.secondary to={"https://matrix.to/#/" <> matrix_username(@actor)} link_text="matrix.to" />
            <KazarmaWeb.Button.secondary to={matrix_scheme_user(@actor)} link_text="matrix:" />
          </:buttons>
        </KazarmaWeb.Address.row>
        <KazarmaWeb.Address.row id="matrix-outbox-room" label={gettext("Outbox room")} value={matrix_outbox_room(@actor)}>
          <:buttons>
            <KazarmaWeb.Button.secondary to={"https://matrix.to/#/" <> matrix_outbox_room(@actor)} link_text="matrix.to" />
            <KazarmaWeb.Button.secondary to={matrix_scheme_room(@actor)} link_text="matrix:" />
          </:buttons>
        </KazarmaWeb.Address.row>
      </div>
    """
  end

  def ap_rows(assigns) do
    ~H"""

      <div class="card card-body bg-base-300 base-100 mt-10">
        <h2 class="text-2xl text-center pt-5">ActivityPub</h2>
        <div class="flex flex-col space-y-2">
          <KazarmaWeb.Address.row id="activitypub-id" label={gettext("ActivityPub ID")} value={ap_id(@actor)}>
            <:buttons>
              <%= link [to: ap_id(@actor), target: "_blank", aria_label: gettext("Open"), title: gettext("Open"), class: "btn btn-secondary"], do: KazarmaWeb.IconView.external_link_icon() %>
            </:buttons>
          </KazarmaWeb.Address.row>
          <KazarmaWeb.Address.row id="activitypub-username" label={gettext("ActivityPub username")} value={ap_username(@actor)}>
            <:buttons></:buttons>
          </KazarmaWeb.Address.row>
        </div>
      </div>
    """
  end

  def timeline(assigns) do
    ~H"""
      <h2 class="text-2xl text-center pt-5">Timeline</h2>
      <%= for object <- @objects do %>
        <KazarmaWeb.Object.show
          actor={@actor} object={object} />
      <% end %>
    """
  end

  def show(assigns) do
    ~H"""
    <div class="">
      <div>
        <.header actor={@actor} />
        <div class="divider"></div> 
        <%= if type(@actor) === "Matrix" do %>
        <.matrix_rows actor={@actor} />
        <.ap_rows actor={@actor} />
        <%= else %>
        <.ap_rows actor={@actor} />
        <.matrix_rows actor={@actor} />
        <% end %>
        <.timeline actor={@actor} objects={@objects} />
      </div>
    </div>
    """
  end
end
