defmodule FsetWeb.ProfileController do
  use FsetWeb, :controller
  alias Fset.Projects

  action_fallback FsetWeb.FallbackController

  def show(conn, params) do
    with {:ok, user} <- Projects.User.with_projects(params["username"]) do
      render(conn, "show.html", user: user)
    end
  end
end
