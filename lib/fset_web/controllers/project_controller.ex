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
  def show(conn, %{"projectname" => p, "username" => u} = params) do
    with {:ok, project} <- Projects.get_head(p),
         is_project_member <- is_project_member(project, conn.assigns[:current_user]),
         %{} = user <- find_project_user(project, u, is_project_member) do
      render(conn, "show.html",
        project: project,
        user: user,
        is_project_unclaimed: project.users == [],
        is_project_member: is_project_member,
        signup_changeset: Accounts.change_user_registration(%Accounts.User{}),
        project_info_changeset: Projects.change_info(project),
        current_file_key: Map.get(params, "filename"),
        project_path: Routes.project_path(conn, :show, u, p)
      )
    end
  end

  def create(conn, _params) do
    case conn.assigns[:current_user] do
      nil = _public ->
        project = Projects.create(%{visibility: :public})
        redirect(conn, to: Routes.project_path(conn, :show, "p", project.key))

      user ->
        project = Projects.create(%{user_id: user.id})
        redirect(conn, to: Routes.project_path(conn, :show, user.username, project.key))
    end
  end

  def update(conn, %{"project" => project_params, "projectname" => projectname}) do
    user = conn.assigns.current_user

    with {:ok, project} <- Projects.get_head(projectname) do
      case Projects.update_info(project, project_params) do
        {:ok, updated_project} ->
          conn
          |> put_flash(:info, "Project info updated successfully.")
          |> redirect(to: Routes.project_path(conn, :show, user.username, updated_project.key))

        {:error, project_info_changeset} ->
          render(conn, "show.html",
            project: project,
            user: user,
            is_project_unclaimed: project.users == [],
            is_project_member: is_project_member(project, conn.assigns[:current_user]),
            signup_changeset: Accounts.change_user_registration(%Accounts.User{}),
            project_info_changeset: project_info_changeset
          )
      end
    end
  end

  defp find_project_user(project, username, is_project_member) do
    case project.users do
      [] ->
        %{username: "public", email: nil}

      _ ->
        case {is_project_member, project} do
          {false, %{visibility: :private}} ->
            nil

          _ ->
            Enum.find(project.users, &(String.downcase(&1.username) == String.downcase(username)))
        end
    end
  end

  defp is_project_member(_, nil), do: false

  defp is_project_member(%{users: users}, current_user),
    do: current_user.id in Enum.map(users, fn a -> a.id end)
end
