defmodule FsetWeb.ImportController do
  use FsetWeb, :controller
  alias Fset.Projects

  def create(conn, params) do
    conn = scrub_params(conn, "import")

    project =
      params
      |> Map.take(["username", "projectname"])
      |> Map.merge(params["import"])
      |> Projects.import(params)

    conn
    |> put_view(FsetWeb.ProjectView)
    |> render("show.html", project: project, username: conn.assigns.current_user.username)
  end
end
