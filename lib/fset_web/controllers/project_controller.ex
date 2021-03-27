defmodule FsetWeb.ProjectController do
  use FsetWeb, :controller
  alias Fset.Projects
  alias Fset.Accounts

  action_fallback FsetWeb.FallbackController

  def show(conn, params) do
    changeset = Accounts.change_user_registration(%Accounts.User{})

    with {:ok, project} <- Projects.get_project(params["projectname"]) do
      render(conn, "show.html",
        project: Projects.to_project_sch(project),
        signup_changeset: changeset
      )
    end
  end

  def create(conn, _params) do
    project = Projects.create()
    redirect(conn, to: Routes.project_path(conn, :show, project.anchor))
  end
end
