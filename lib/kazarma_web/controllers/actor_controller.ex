defmodule KazarmaWeb.ActorController do
  use KazarmaWeb, :controller

  def show(conn, %{"username" => username}) do
    case ActivityPub.Actor.get_or_fetch_by_username(username) do
      {:ok, actor} ->
        conn
        |> fetch_session()
        |> fetch_flash()
        |> protect_from_forgery()
        |> put_layout({KazarmaWeb.LayoutView, "app.html"})
        |> put_view(KazarmaWeb.ActorView)
        |> render("show.html", actor: actor)

      _ ->
        conn
        |> fetch_session()
        |> fetch_flash()
        |> protect_from_forgery()
        |> put_layout({KazarmaWeb.LayoutView, "app.html"})
        |> put_view(KazarmaWeb.SearchView)
        |> put_flash(:error, "Error fetching user")
        |> render("index.html")
    end
  end
end
