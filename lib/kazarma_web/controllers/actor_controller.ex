defmodule KazarmaWeb.ActorController do
  use KazarmaWeb, :controller

  def show(conn, %{"username" => username}) do
    get_actor_function =
      if Application.get_env(:kazarma, :html_actor_view_include_remote, false) do
        :get_or_fetch_by_username
      else
        :get_cached_by_username
      end

    case apply(ActivityPub.Actor, get_actor_function, [username]) do
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
        |> put_flash(:error, gettext("User not found"))
        |> redirect(to: Routes.index_path(conn, :index))
    end
  end
end
