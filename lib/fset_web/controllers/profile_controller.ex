defmodule FsetWeb.ProfileController do
  use FsetWeb, :controller
  alias Fset.Projects

  action_fallback FsetWeb.FallbackController

  def show(conn, params) do
    case conn.assigns[:current_user] do
      nil ->
        with {:ok, user} <- Projects.by_username(params["username"]) do
          render(conn, "show.html", projects: user.projects, user: user)
        end

      user ->
        user = Projects.by_user(user)
        render(conn, "show.html", projects: user.projects)
    end
  end
end
