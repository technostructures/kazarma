# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Index do
  @moduledoc false

  use KazarmaWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    put_session_locale(session)

    {:ok,
     socket
     |> assign(help: Kazarma.Config.frontpage_help())
     |> assign(before_text: Kazarma.Config.frontpage_before_text())
     |> assign(after_text: Kazarma.Config.frontpage_after_text())}
  end

  @impl true
  def handle_event("search", %{"search" => %{"address" => address}}, socket) do
    case Kazarma.search_user(address) do
      %{} = actor ->
        actor_path = Kazarma.ActivityPub.Adapter.actor_path(actor)

        # dirty fix because LiveView does not re-enable the form when redirecting
        send(self(), {:redirect, actor_path})
        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("User not found"))}
    end
  end

  @impl true
  def handle_info({:redirect, to}, socket) do
    {:noreply, push_navigate(socket, to: to)}
  end
end
