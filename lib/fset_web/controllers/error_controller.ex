defmodule FsetWeb.ErrorController do
  use FsetWeb, :controller

  def notfound(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_layout({FsetWeb.LayoutView, "static.html"})
    |> put_view(FsetWeb.ErrorView)
    |> render(:"404")
  end
end
