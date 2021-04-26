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
  def show(conn, %{"projectname" => projectname, "username" => username}) do
    changeset = Accounts.change_user_registration(%Accounts.User{})

    with {:ok, project} <- Projects.get_project(projectname, preload: [:users]),
         %{} = user <- find_project_user(project, username) do
      render(conn, "show.html",
        project: project,
        user: user,
        is_project_unclaimed: project.users == [],
        is_project_member: is_project_member(project, conn.assigns[:current_user]),
        signup_changeset: changeset
      )
    end
  end

  def create(conn, _params) do
    case conn.assigns[:current_user] do
      nil = _public ->
        project = Projects.create()
        redirect(conn, to: Routes.project_path(conn, :show, "p", project.key))

      user ->
        project = Projects.create(%{user_id: user.id})
        redirect(conn, to: Routes.project_path(conn, :show, user.username, project.key))
    end
  end

  defp find_project_user(project, username) do
    case project.users do
      [] -> %{username: "public", email: nil}
      _ -> Enum.find(project.users, &(&1.username == username))
    end
  end

  defp is_project_member(_, nil), do: false

  defp is_project_member(%{users: users}, current_user),
    do: current_user.id in Enum.map(users, fn a -> a.id end)
end
