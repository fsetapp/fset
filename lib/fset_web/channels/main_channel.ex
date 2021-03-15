defmodule FsetWeb.MainChannel do
  use FsetWeb, :channel
  alias Fset.Projects

  def join("project:" <> project_name, _params, socket) do
    case Projects.get_project(project_name) do
      {:ok, project} ->
        {:ok, project, socket}

      _ ->
        {:ok, socket}
    end
  end

  def handle_in("save_project", store, socket) do
    {:noreply, assign(socket, :store, store)}
  end
end
