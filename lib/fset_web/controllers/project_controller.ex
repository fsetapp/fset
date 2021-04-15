defmodule FsetWeb.ProjectController do
  use FsetWeb, :controller
  alias Fset.Projects
  alias Fset.Accounts

  action_fallback FsetWeb.FallbackController

  @doc """
  show.html page is the same for authorized user and guess, except,
  for guess, we soft cut communication between socket client and server; prevent
  channel push on client and ignore handling event from server.
  """
  def show(conn, %{"projectname" => projectname} = params) do
    username = Map.get(params, "username", {:ok, "public"})

    find_project_user = fn
      _project, {:ok, "public"} -> %{username: "public"}
      project, username -> Enum.find(project.users, fn u -> u.username == username end)
    end

    case conn.assigns[:current_user] do
      nil ->
        changeset = Accounts.change_user_registration(%Accounts.User{})

        with {:ok, project} <- Projects.get_project(projectname),
             %{username: uname} <- find_project_user.(project, username) do
          render(conn, "show.html",
            project: project,
            signup_changeset: changeset,
            project_users: project.users,
            username: uname
          )
        end

      _user ->
        with {:ok, project} <- Projects.get_project(projectname),
             %{username: uname} <- find_project_user.(project, username) do
          render(conn, "show.html", project: project, username: uname)
        end
    end
  end

  def create(conn, _params) do
    case conn.assigns[:current_user] do
      nil = _public ->
        project = Projects.create()
        redirect(conn, to: Routes.project_path(conn, :show, project.key))

      user ->
        project = Projects.create(%{user_id: user.id})
        redirect(conn, to: Routes.project_path(conn, :show, user.username, project.key))
    end
  end
end
