defmodule FsetWeb.ProjectController do
  use FsetWeb, :controller
  alias Fset.DevFixtures
  alias Fset.Accounts

  def show(conn, params) do
    changeset = Accounts.change_user_registration(%Accounts.User{})
    project = get_project(params)

    render(conn, "show.html", project: project, signup_changeset: changeset)
  end

  def create(conn, _params) do
    project = create_project(%{key: "unclaimed_project"})
    redirect(conn, to: Routes.project_path(conn, :show, project.key))
  end

  defp create_project(%{key: _}) do
    hd(DevFixtures.projects())
  end

  defp get_project(%{"projectname" => name}) do
    Enum.find(DevFixtures.projects(), fn p -> p.key == name end)
  end
end
