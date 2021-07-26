defmodule FsetWeb.FallbackController do
  use Phoenix.Controller

  @moduledoc """
  Common contracts for function calls' result in controller.
  Layout contains minimal assets necessarily.
  """
  def call(conn, nil), do: call(conn, {:error, :not_found})

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_layout({FsetWeb.LayoutView, "static.html"})
    |> put_view(FsetWeb.ErrorView)
    |> render("404.html")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(403)
    |> put_layout({FsetWeb.LayoutView, "static.html"})
    |> put_view(FsetWeb.ErrorView)
    |> render("403.html")
  end
end
