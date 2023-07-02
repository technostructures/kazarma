# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.Components.Profile do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML
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
    <div class="tooltip max-w-full" data-tip={gettext("Click to open")}>
      <div class="max-w-full overflow-hidden text-ellipsis">
        <.link href={@to} target="_blank" aria-label={gettext("Open")} class="link link-hover">
          <%= @address %>
        </.link>
      </div>
    </div>
    """
  end

  defp address_that_copies(assigns) do
    ~H"""
    <div class="tooltip max-w-full" data-tip={gettext("Click to copy")}>
      <div class="max-w-full overflow-hidden text-ellipsis">
        <.link href="#" aria-label={gettext("Copy")} data-copy={@address} class="link link-hover">
          <%= @address %>
        </.link>
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

  def original_profile(assigns) do
    ~H"""
    <div class="card shadow-lg bg-base-100 flex flex-row base-100">
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
      <div class="card-body max-w-full p-6">
        <div class="card-title flex flex-row">
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

  def actions_modal(%{actor: %ActivityPub.Actor{local: true}} = assigns) do
    ~H"""
    <KazarmaWeb.CoreComponents.modal id="actions-modal">
      <h2>
        <%= gettext("Interact with %{name}", name: display_name(@actor)) %>
      </h2>
      <h3>
        <%= gettext("Send a Direct Message (DM)") %>
      </h3>
      <p>
        <%= gettext("Compatible platform: Mastodon, Pleroma.") %>
      </p>
      <p>
        <%= gettext("This user can receive direct messages (posts with a \"private\" visibility.") %>
      </p>
      <h3>
        <%= gettext("Start a 1-to-1 chat") %>
      </h3>
      <p>
        <%= gettext("Compatible platform: Pleroma.") %>
      </p>
      <p>
        <%= gettext("Start a new chat with this user by entering their ActivityPub address.") %>
      </p>
      <h3>
        <%= gettext("Mention this user") %>
      </h3>
      <p>
        <%= gettext("This user can be mentioned in a public post.") %>
        <%= gettext("If you are bridged, they will be invited to your room to see your mention.") %>
      </p>
      <h3>
        <%= gettext("Add in a group") %>
      </h3>
      <p>
        <%= gettext("Compatible platform: Mobilizon.") %>
      </p>
      <p>
        <%= gettext(
          "If your Mobilizon intance federates with Kazarma, you can add this user to a group."
        ) %>
        <%= gettext("They will be able to participate in group discussions.") %>
      </p>
    </KazarmaWeb.CoreComponents.modal>
    """
  end

  def actions_modal(%{actor: %ActivityPub.Actor{local: false}} = assigns) do
    assigns = assign(assigns, :outbox_room, outbox_room(assigns.actor))

    ~H"""
    <KazarmaWeb.CoreComponents.modal id="actions-modal">
      <h2>
        <%= gettext("Interact with %{name}", name: display_name(@actor)) %>
      </h2>
      <h3>
        <%= gettext("Send a Direct Message (DM)") %>
      </h3>
      <p>
        <%= gettext("Compatible platform: Mastodon, Pleroma.") %>
      </p>
      <p>
        <%= gettext("Start a DM with this user by inviting them to a private non-encrypted room.") %>
      </p>
      <h3>
        <%= gettext("Start a 1-to-1 chat") %>
      </h3>
      <p>
        <%= gettext("Compatible platform: Pleroma.") %>
      </p>
      <p>
        <%= gettext("Start a 1-to-1 chat with this user by starting a new direct conversation.") %>
      </p>
      <h3 :if={@outbox_room}>
        <%= gettext("See their public activity") %>
      </h3>
      <p :if={@outbox_room}>
        <%= gettext("This user has opted-in to public activity bridging.") %>
        <%= gettext("You can join their room and reply to their posts.") %>
        <%= gettext(
          "If you send a message to their room that is not a reply, it will send a public post mentioning them."
        ) %>
      </p>
    </KazarmaWeb.CoreComponents.modal>
    """
  end

  def puppet_profile(assigns) do
    ~H"""
    <div class="card shadow-lg bg-accent base-100 mt-4">
      <div class="card-body p-6">
        <div class="flex flex-row justify-center">
          <div class="mr-2"><%= opposite_type_icon(@actor) %></div>
          via
          <div class="ml-2"><KazarmaWeb.Components.Icon.kazarma_icon /></div>
        </div>
        <div class="flex flex-row items-center justify-center">
          <div class="max-w-full min-w-0 flex flex-col">
            <.puppet_addresses actor={@actor} />
          </div>
          <div class="">
            <button
              class="btn btn-circle btn-primary min-h-0 h-6 w-6 ml-4"
              phx-click={KazarmaWeb.CoreComponents.show_modal("actions-modal")}
            >
              <%= gettext("?") %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def show(assigns) do
    ~H"""
    <div>
      <.original_profile actor={@actor} />
      <!-- <div class="divider"></div> -->
      <.puppet_profile actor={@actor} />
    </div>
    """
  end
end
