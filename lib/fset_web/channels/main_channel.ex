defmodule FsetWeb.MainChannel do
  use FsetWeb, :channel
  alias Fset.Projects

  def join("project:" <> project_name, _params, socket) do
    case Projects.get_project(project_name) do
      {:ok, project} ->
        send(self(), {:build_ids_lookup_table, project.anchor})

        {:ok, Projects.to_project_sch(project), assign(socket, :project, %{project | files: []})}

      _ ->
        {:ok, socket}
    end
  end

  def handle_in("push_sch_meta", sch_meta, socket) do
    reply = Projects.persist_metadata(sch_meta, socket.assigns.project)
    {:reply, reply, socket}
  end

  def handle_in("push_project", diff, socket) do
    {:ok, _project} = Projects.persist_diff(diff, socket.assigns.project)
    {:ok, project} = Projects.get_project(socket.assigns.project.anchor)

    send(self(), {:build_ids_lookup_table, socket.assigns.project.anchor})

    {:reply, {:ok, Projects.to_project_sch(project)}, socket}
  end

  def handle_info({:build_ids_lookup_table, project_anchor}, socket) do
    {:ok, project} = Projects.get_project(project_anchor)

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
end
