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

    project_show_path =
      Routes.project_path(conn, :show, conn.assigns.current_user.username, project.key)

    conn
    |> put_view(FsetWeb.ProjectView)
    |> redirect(to: project_show_path)
  end
end
