# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.ActorAddresses do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.Helpers
  import KazarmaWeb.Gettext

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

  def show(assigns) do
    ~H"""
    <%= if type(@actor) === "Matrix" do %>
    <.matrix_rows actor={@actor} />
    <.ap_rows actor={@actor} />
    <%= else %>
    <.ap_rows actor={@actor} />
    <.matrix_rows actor={@actor} />
    <% end %>
    """
  end
end
