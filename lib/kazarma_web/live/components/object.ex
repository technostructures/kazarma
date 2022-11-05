# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Components.Object do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.Helpers
  import KazarmaWeb.Gettext

  def datetime(%ActivityPub.Object{data: %{"published" => published}}) do
    with {:ok, dt, _n} <- published |> DateTime.from_iso8601(),
         {:ok, str} <- KazarmaWeb.Cldr.DateTime.to_string(dt) do
      str
    end
  end

  def datetime(_) do
    ""
  end

  def display_body(assigns) do
    ~H(<%= raw(text_content(@object\)\) %>)
  end

  def header(assigns) do
    ~H"""
    <div class="flex flex-row items-center">
      <div>
        <%= unless is_nil(avatar_url(@actor)) do %>
          <div class="avatar">
            <div class="rounded-full w-12 h-12 shadow">
              <img
                src={avatar_url(@actor)}
                alt={gettext("%{actor_name}'s avatar", actor_name: @actor.data["name"])}
              />
            </div>
          </div>
        <% end %>
      </div>
      <div class="">
        <h1 class="card-title text-xl">
          <.link navigate={
            KazarmaWeb.Router.Helpers.activity_pub_path(@socket, :actor, @actor.username)
          }>
            <%= display_name(@actor) %>
          </.link>
        </h1>
      </div>
      <div class="text-sm ml-auto">
        <.link navigate={KazarmaWeb.Router.Helpers.activity_pub_path(@socket, :object, @object.id)}>
          <%= datetime(@object) %>
        </.link>
      </div>
    </div>
    """
  end

  attr :object, :map
  attr :actor, :map
  attr :conn, :map
  attr :reply, :boolean, default: false
  attr :classes, :string, default: ""

  def show(assigns) do
    ~H"""
    <div
      id={@object.data["id"]}
      class={"card shadow-lg side bg-base-100 mt-4 flex flex-row #{@classes}"}
    >
      <div class="card-body">
        <.header actor={@actor} object={@object} socket={@socket} />
        <div class="mt-0 mb-0 divider"></div>
        <p class="">
          <.display_body object={@object} />
        </p>
      </div>
      <div :if={@reply} class="align-center">
        <%= KazarmaWeb.IconView.reply_icon() %>
      </div>
    </div>
    """
  end
end
