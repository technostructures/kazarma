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

  def show(%{object: object} = assigns) when is_binary(object), do: show_redirect_link(assigns)

  def show(%{object: %ActivityPub.Object{data: %{"type" => "Note"}}} = assigns),
    do: show_note(assigns)

  def show(%{object: %ActivityPub.Object{data: %{"id" => _id}}} = assigns),
    do: show_redirect_link(assigns)

  def show_redirect_link(assigns) do
    ~H"""
    <div class={"card shadow-lg side bg-base-100 mt-4 flex flex-row items-center #{@classes}"}>
      <div :if={@type == :reply} class="self-start align-center">
        <.reply_icon class="w-10 h-10 m-2 -mr-4 self-start reply_icon" />
      </div>
      <div class="card-body p-4">
        <div class="flex">
          <.link href={@object.data["id"]} class="btn mx-auto" title={gettext("Open")}>
            <%= gettext("Open") %>
          </.link>
        </div>
      </div>
      <div :if={@type == :replied_to} class="self-end align-center">
        <.replied_icon class="w-10 h-10 m-2 -ml-5 replied_icon" />
      </div>
    </div>
    """
  end

  defp avatar(assigns) do
    ~H"""
    <%= case avatar_url(@actor) do %>
      <% nil -> %>
        <KazarmaWeb.Components.Hashvatar.hashvatar
          identifier={main_address(@actor)}
          variant={:stagger}
          line_color="#fffaf0"
        />
      <% url -> %>
        <img src={url} alt={gettext("%{actor_name}'s avatar", actor_name: @actor.data["name"])} />
    <% end %>
    """
  end

  def show_note(assigns) do
    ~H"""
    <div
      id={@object.data["id"]}
      class={"card shadow-lg side bg-base-100 mt-4 flex flex-row items-center #{if @type == :main, do: "bg-accent"} #{@classes}"}
    >
      <div :if={@type == :reply} class="self-start align-center">
        <.reply_icon class="w-10 h-10 m-2 -mr-4 self-start reply_icon" />
      </div>
      <div>
        <div class="avatar">
          <div class="rounded-full w-24 h-24 my-4 ml-4 shadow">
            <.link
              navigate={Kazarma.ActivityPub.Adapter.actor_path(@actor)}
              class="link link-hover"
              title={main_address(@actor)}
            >
              <.avatar actor={@actor} />
            </.link>
          </div>
        </div>
      </div>
      <div class="card-body p-4">
        <.header actor={@actor} object={@object} socket={@socket} />
        <div class={"mt-0 mb-0 divider #{if @type == :main, do: "before:bg-[#ffb7a4] after:bg-[#ffb7a4]"}"} />
        <p class="object-content">
          <.display_body object={@object} />
        </p>
      </div>
      <div :if={@type == :replied_to} class="self-end align-center reply_icon">
        <.replied_icon class="w-10 h-10 m-2 -ml-5 replied_icon" />
      </div>
    </div>
    """
  end
end
