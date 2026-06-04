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
        conn = put_layout(conn, {FsetWeb.LayoutView, "static.html"})
        render(conn, "landing.html", docs: DocsSample.types())
        # Steps for regenerating _fmodel-examples.html.eex
        # 1. put <script defer type="module" src="<%= Routes.static_path(@conn, "/assets/docs_page.js") %>"></script> on static.html
        # 2. Inside landing.html, change <%= render "_fmodel_examples.html", assigns %> to <%= render "__gen_fmodel_examples.html", assigns %>
        # 3. change `render(conn, "landing.html")` to `render(conn, "landing.html", docs: DocsSample.types())` above
        # 4. go to browser copy html and put it on lib/fset_web/templates/page/_fmodel_examples.html.eex
        # Then revert 1-3.
    end
  end

  def pricing(conn, _params) do
    render(conn, "pricing.html", plans: Payments.plans())
  end

  def roadmap(conn, _params) do
    conn = put_layout(conn, {FsetWeb.LayoutView, "docs.html"})
    render(conn, "roadmap.html", plans: Payments.plans())
  end

  def docs(conn, _params) do
    conn = put_layout(conn, {FsetWeb.LayoutView, "docs.html"})
    render(conn, "docs.html", docs: DocsSample.types())
  end
end
