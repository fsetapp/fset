defmodule FsetWeb.PageController do
  use FsetWeb, :controller
  alias Fset.Projects
  alias Fset.Accounts

  def index(conn, _params) do
    with %{current_user: %Accounts.User{} = user} <- conn.assigns,
         user_ <- Projects.by_user(user),
         project <- hd(user_.projects) do
      redirect(conn, to: Routes.project_path(conn, :show, user.email, project.key))
    else
      _ ->
        render(conn, "index.html")
    end
  end
end
