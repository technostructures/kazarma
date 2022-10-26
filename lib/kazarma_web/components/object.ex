# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Object do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.ObjectView
  import KazarmaWeb.ActorView
  import KazarmaWeb.Gettext

  def datetime(%ActivityPub.Object{data: %{"published" => published}}) do
    with {:ok, dt, n} <- published |> DateTime.from_iso8601(),
         {:ok, str} <- KazarmaWeb.Cldr.DateTime.to_string(dt) do
      str
    end
  end

  def datetime(_) do
    ""
  end

  def display_body(assigns) do
    ~H(<div class=""><%= raw text_content @object %></div>)
  end

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
            <a href={ap_id(@actor)}>
              <%= display_name(@actor) %>
            </a>
          </h1>
        </div>
        <div class="">
          <div class="badge badge-lg">
            <%= type(@actor) %>
          </div>
        </div>
        <div style="margin-left: auto;">
          <%= datetime(@object) %>
        </div>
      </div>
    """
  end

  def show(assigns) do
    ~H"""
    <div class="card shadow-lg side bg-base-100 mt-10">
      <div class="card-body">
        <.header actor={@actor} object={@object} />
        <div class="mt-0 mb-0 divider"></div>
        <div class="flex flex-col space-y-2 ">
          <p class="text-lg font-medium"><.display_body object={@object} /></p>
        </div>
      </div>
    </div>
    """
  end
end
