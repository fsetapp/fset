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
        render(conn, "landing.html")
        # For generate example of types on landing page
        # 1. Also put <script defer type="module" src="<%= Routes.static_path(@conn, "/assets/docs_page.js") %>"></script> on static.html (layout)
        # 2. Inside landing.html has to have <%= render "__gen_fmodel_examples.html", assigns %>
        # 3. copy the [data-ext="fmodel"] html on browser and paste it to _fmodel.example.html
        # render(conn, "landing.html", docs: DocsSample.types())
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
