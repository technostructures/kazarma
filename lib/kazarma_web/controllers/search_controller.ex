# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.SearchController do
  use KazarmaWeb, :controller

  plug :halt_if_disabled

  def search(conn, %{"search" => %{"address" => address}}) do
    case Kazarma.search_user(address) do
      {:ok, actor} ->
        actor_path = Kazarma.ActivityPub.Adapter.actor_path(actor)
        redirect(conn, to: actor_path)

      _ ->
        conn
        |> put_flash(:error, gettext("User not found"))
        |> redirect(to: Routes.index_path(conn, :index))
    end
  end

  defp halt_if_disabled(conn, _opts) do
    if Application.get_env(:kazarma, :html_search, false) do
      conn
    else
      conn |> redirect(to: "/") |> halt()
    end
  end
end
