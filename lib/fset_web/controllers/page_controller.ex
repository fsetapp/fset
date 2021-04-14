defmodule FsetWeb.PageController do
  use FsetWeb, :controller
  alias Fset.Accounts

  def index(conn, _params) do
    with %{current_user: %Accounts.User{} = user} <- conn.assigns do
      redirect(conn, to: Routes.profile_path(conn, :show, user.username))
    else
      _ ->
        render(conn, "index.html")
    end
  end
end
