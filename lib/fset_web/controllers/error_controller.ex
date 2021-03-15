defmodule FsetWeb.ErrorController do
  use FsetWeb, :controller

  def notfound(conn, _params) do
    FsetWeb.FallbackController.call(conn, {:error, :not_found})
  end
end
