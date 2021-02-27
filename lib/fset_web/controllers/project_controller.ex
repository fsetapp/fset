defmodule FsetWeb.ProjectController do
  use FsetWeb, :controller
  alias Fset.DevFixtures

  def show(conn, params) do
    project = get_project(params)
    render(conn, "show.html", %{project: project})
  end

  def create(conn, _params) do
    project = create_project(%{name: "unclaimed_project"})
    redirect(conn, to: Routes.project_path(conn, :show, project.name))
  end

  defp create_project(%{name: _}) do
    hd(DevFixtures.projects())
  end

  defp get_project(%{"projectname" => name}) do
    Enum.find(DevFixtures.projects(), fn p -> p.name == name end)
  end
end
