defmodule FsetWeb.MainChannel do
  use FsetWeb, :channel
  alias Fset.Projects
  alias Fset.Payments

  def join("project:" <> project_name, params, socket) do
    {:ok, project_name} = Phoenix.Token.verify(socket, "project name", project_name)

    case Projects.get_project(project_name) do
      {:ok, project} ->
        send(self(), {:build_ids_lookup_table, project})

        {:ok, Projects.to_project_sch(project, params),
         assign(socket, :project, %{project | files: []})}

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
    %{project: project} = socket.assigns
    user_id = Map.get(socket.assigns, :current_user)

    if authorized(project, user_id) do
      {_result, _project} = Projects.persist_diff(diff, project)
      {:ok, project} = Projects.get_project(project.key)

      send(self(), {:build_ids_lookup_table, project})
      project_sch = Projects.to_project_sch(project)
      send(self(), {:prune_sch_metas, project_sch, project.id})

      {:reply, {:ok, project_sch}, socket}
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

  def handle_info({:prune_sch_metas, project_sch, project_id}, socket) do
    Projects.prune_sch_metas(project_id, project_sch)
    {:noreply, socket}
  end

  defp authorized(%{users: []}, _), do: true

  defp authorized(project, user_id) do
    with %{} = user <- Enum.find(project.users, fn u -> u.id == user_id end),
         %{} = sub <- Payments.load_subscription(user).subscription,
         {:ok, effective_date} <- Date.from_iso8601(Payments.cancellation_effective_date(sub)) do
      Date.compare(Date.utc_today(), effective_date) == :lt
    else
      _ ->
        false
    end
  end

  # You will know it when you want it
  # def terminate({_, trace}, _socket) do
  #   IO.inspect(trace, label: "terminate trace")
  # end
end
