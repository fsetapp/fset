defmodule FsetWeb.MainChannel do
  use FsetWeb, :channel
  alias Fset.DevFixtures

  def join("project:" <> project_name, _params, socket) do
    {:ok, project} = get_project(nil, project_name)
    {:ok, project, socket}
  end

  def handle_in("save_project", store, socket) do
    {:noreply, assign(socket, :store, store)}
  end

  defp get_project(_user_id, _project_name) do
    {:ok, hd(DevFixtures.projects())}
  end
end
