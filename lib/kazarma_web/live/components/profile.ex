# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.Profile do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.Helpers
  import KazarmaWeb.Gettext
  alias KazarmaWeb.Components.ActorLinks

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
          <h1 class="card-title text-2xl">
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

  def show(assigns) do
    ~H"""
    <div class="container mx-auto flex flex-col lg:max-w-3xl px-4">
      <.header actor={@actor} />
      <div class="divider"></div> 
      <KazarmaWeb.Components.ActorAddresses.show actor={@actor} />
    </div>
    """
  end
end
