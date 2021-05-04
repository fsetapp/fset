defmodule FsetWeb.PingController do
  use FsetWeb, :controller
  import Ecto.Query

  def appstart(conn, _params) do
    [version] =
      Fset.Repo.one(
        from m in "schema_migrations",
          order_by: {:desc, m.inserted_at},
          limit: 1,
          select: [m.version]
      )

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "#{version}")
  end
end
