defmodule FsetWeb.MainChannel do
  use FsetWeb, :channel
  alias Fset.Projects

  def join("project:" <> project_name, _params, socket) do
    case Projects.get_project(project_name) do
      {:ok, project} ->
        send(self(), {:build_ids_lookup_table, project})

        {:ok, Projects.to_project_sch(project), assign(socket, :project, %{project | files: []})}

      _ ->
        {:ok, socket}
    end
  end

  def handle_in("push_sch_meta", sch_meta, socket) do
    %{project: project, current_user: user_id} = socket.assigns

    if authorized(project, user_id) do
      reply = Projects.persist_metadata(sch_meta, project)
      {:reply, reply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_in("push_project", diff, socket) do
    %{project: project, current_user: user_id} = socket.assigns

    if authorized(project, user_id) do
      {_result, _project} = Projects.persist_diff(diff, project)
      {:ok, project} = Projects.get_user_project(project.key, user_id)

      send(self(), {:build_ids_lookup_table, project})

      {:reply, {:ok, Projects.to_project_sch(project)}, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:build_ids_lookup_table, project}, socket) do
    map_fmodel = fn m ->
      m
      |> Map.from_struct()
      |> Map.take([:id, :anchor])
    end

    map_file = fn f ->
      f
      |> Map.from_struct()
      |> Map.take([:id, :anchor])
      |> Map.put(:fmodels, Enum.map(f.fmodels, map_fmodel))
    end

    project = %{project | files: Enum.map(project.files, map_file)}

    {:noreply, assign(socket, :project, project)}
  end

  defp authorized(project, user_id) do
    user_id in Enum.map(project.users, fn u -> u.id end)
  end

  # You will know it when you want it
  # def terminate({_, trace}, _socket) do
  #   IO.inspect(trace, label: "terminate trace")
  # end
end
