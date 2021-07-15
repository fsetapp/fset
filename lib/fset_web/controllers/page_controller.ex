defmodule FsetWeb.PageController do
  use FsetWeb, :controller
  alias Fset.Accounts
  alias Fset.Payments
  alias Fset.DocsSample

  def index(conn, _params) do
    with %{current_user: %Accounts.User{} = user} <- conn.assigns do
      redirect(conn, to: Routes.profile_path(conn, :show, user.username))
    else
      _ ->
        render(conn, "index.html")
    end
  end

  def pricing(conn, _params) do
    render(conn, "pricing.html", plans: Payments.plans())
  end

  def docs(conn, _params) do
    conn = put_layout(conn, {FsetWeb.LayoutView, "docs.html"})
    render(conn, "docs.html", docs: DocsSample.types())
  end
end
