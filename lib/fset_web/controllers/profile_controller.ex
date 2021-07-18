defmodule FsetWeb.ProfileController do
  use FsetWeb, :controller
  alias Fset.Projects

  action_fallback FsetWeb.FallbackController

  def show(conn, params) do
    with {:ok, user} <- Projects.User.with_projects(params["username"]) do
      user =
        case conn.assigns[:current_user] do
          u when u.id == user.id ->
            user

          _ ->
            %{user | projects: Enum.filter(user.projects, fn p -> p.visibility != :private end)}
        end

      render(conn, "show.html", user: user)
    end
  end
end
