defmodule KazarmaWeb.SearchController do
  use KazarmaWeb, :controller

  def search(conn, %{"search" => %{"address" => address}}) do
    case Kazarma.search_user(address) do
      {:ok, actor} ->
        actor_path = Routes.activity_pub_path(conn, :actor, actor.username)
        redirect(conn, to: actor_path)

      _ ->
        conn
        |> put_flash(:error, "Not found")
        |> redirect(to: Routes.index_path(conn, :index))
    end
  end
end
