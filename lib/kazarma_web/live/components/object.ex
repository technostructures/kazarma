# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Components.Object do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
  import KazarmaWeb.Components.Icon
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
    <div class="flex flex-row flex-wrap items-center">
      <div class="grow">
        <h1 class="card-title text-xl">
          <.link
            navigate={Kazarma.ActivityPub.Adapter.actor_path(@actor)}
            class="link link-hover"
            title={main_address(@actor)}
          >
            <%= display_name(@actor) %>
          </.link>
        </h1>
      </div>
      <div class="text-sm grow-0">
        <.link
          navigate={Kazarma.ActivityPub.Adapter.object_path(@object, @actor)}
          class="link link-hover"
        >
          <%= datetime(@object) %>
        </.link>
      </div>
    </div>
    """
  end

  attr :object, :map
  attr :actor, :map
  attr :socket, :map
  attr :type, :atom, default: nil
  attr :classes, :string, default: ""

  def show(assigns) do
    ~H"""
    <div
      id={@object.data["id"]}
      class={"card shadow-lg side bg-base-100 mt-4 flex flex-row items-center #{if @type == :main, do: "bg-accent"} #{@classes}"}
    >
      <div :if={@type == :reply} class="self-start align-center">
        <.reply_icon class="w-10 h-10 m-2 -mr-4 self-start" />
      </div>
      <div>
        <%= unless is_nil(avatar_url(@actor)) do %>
          <div class="avatar">
            <div class="rounded-full w-24 h-24 my-4 ml-4 shadow">
              <img
                src={avatar_url(@actor)}
                alt={gettext("%{actor_name}'s avatar", actor_name: @actor.data["name"])}
              />
            </div>
          </div>
        <% end %>
      </div>
      <div class="card-body p-4">
        <.header actor={@actor} object={@object} socket={@socket} />
        <div class={"mt-0 mb-0 divider #{if @type == :main, do: "before:bg-[#ffb7a4] after:bg-[#ffb7a4]"}"}>
        </div>
        <p class="">
          <.display_body object={@object} />
        </p>
      </div>
      <div :if={@type == :replied_to} class="self-end align-center">
        <.replied_icon class="w-10 h-10 m-2 -ml-5" />
      </div>
    </div>
    """
  end
end
