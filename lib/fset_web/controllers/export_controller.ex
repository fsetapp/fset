defmodule FsetWeb.ExportController do
  use FsetWeb, :controller
  alias Fset.Projects

  def inline(conn, params) do
    exported = Projects.export_as_binary(Map.take(params, ["projectname", "username", "export"]))

    send_download(conn, {:binary, exported},
      filename: params["projectname"] <> ".json",
      disposition: :inline,
      content_type: "application/json",
      charset: "utf-8"
    )
  end

  def download(conn, params) do
    exported = Projects.export_as_binary(Map.take(params, ["projectname", "username", "export"]))
    send_download(conn, {:binary, exported}, filename: params["projectname"] <> ".json")
  end
end
