defmodule FsetWeb.ErrorViewTest do
  use FsetWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.html", %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :phoenix_endpoint, FsetWeb.Endpoint)
    html = render_to_string(FsetWeb.ErrorView, "404.html", conn: conn)

    assert html =~ "Not Found"
  end

  test "renders 500.html", %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :phoenix_endpoint, FsetWeb.Endpoint)
    html = render_to_string(FsetWeb.ErrorView, "500.html", conn: conn)

    assert html =~ "Internal Server Error"
  end
end
