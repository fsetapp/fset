defmodule FsetWeb.MainChannel do
  use FsetWeb, :channel
  alias Fset.Projects
  alias Fset.Payments

  @diffed_topic "project_diffs_result:"

  def join("project:" <> project_name, params, socket) do
    {:ok, project_name} = Phoenix.Token.verify(socket, "project name", project_name)
    # TODO: handle session from token expired
    # {:error, :expired}
    t1 = :os.system_time(:millisecond)

    case Projects.get_project(project_name) do
      {:ok, project} ->
        Phoenix.PubSub.subscribe(Fset.PubSub, @diffed_topic <> project.anchor)
        send(self(), {:build_ids_lookup_table, project})
        t2 = inspect_time_from(t1, "get_project")

        project_sch = Projects.to_project_sch(project, params)
        _t3 = inspect_time_from(t2, "to_project_sch")

        {files, project_sch_head} = Map.pop(project_sch, "fields")

        chuck_count = 4
        chuck_size = div(Enum.count(files), chuck_count)

        batches =
          if chuck_size > 1,
            do: Enum.chunk_every(files, chuck_size),
            else: [files]

        send(self(), {:push_each_batch, batches})

        {:ok, project_sch_head, assign(socket, :project, %{project | files: []})}

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
      {persisted_diff_result, _project_ids_lookup} = Projects.persist_diff(diff, project)

      Phoenix.PubSub.broadcast_from!(
        Fset.PubSub,
        self(),
        @diffed_topic <> project.anchor,
        {:persisted_diff_result, persisted_diff_result}
      )

      send(self(), {:post_persisted_task, project.key})

      {:reply, {:ok, persisted_diff_result}, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_persisted_task, project_key}, socket) do
    {:ok, project} = Projects.get_project(project_key)
    send(self(), {:build_ids_lookup_table, project})
    send(self(), {:prune_sch_metas, project, project.id})
    # TODO: only push changed sch_metas as a part of persisted_diff_result
    # And mergeSchMetas on client (at the end of persisted_diff_result)
    send(self(), {:push_sch_metas, :post_persisted})
    send(self(), {:push_referrers, :post_persisted})
    {:noreply, socket}
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

  def handle_info({:push_each_batch, []}, socket) do
    push(socket, "each_batch_finished", %{batch: []})
    send(self(), {:push_sch_metas, :initial})
    {:noreply, socket}
  end

  def handle_info({:push_each_batch, [batch | batches]}, socket) do
    send(self(), {:push_each_batch, batches})
    push(socket, "each_batch", %{batch: batch})
    {:noreply, socket}
  end

  def handle_info({:push_sch_metas, phase}, socket) do
    sch_metas_map = Projects.sch_metas_map(socket.assigns.project)
    push(socket, "sch_metas_map", %{schMetas: sch_metas_map, phase: phase})
    send(self(), {:push_referrers, phase})
    {:noreply, socket}
  end

  def handle_info({:push_referrers, phase}, socket) do
    referrers_map = Projects.referrers_map(socket.assigns.project)
    push(socket, "referrers_map", %{referrers: referrers_map, phase: phase})
    {:noreply, socket}
  end

  def handle_info({:prune_sch_metas, project, project_id}, socket) do
    project_sch = Projects.to_project_sch(project)
    Projects.prune_sch_metas(project_id, project_sch)
    {:noreply, socket}
  end

  def handle_info({:persisted_diff_result, persisted_diff_result}, socket) do
    send(self(), {:post_persisted_task, socket.assigns.project.key})
    push(socket, "persisted_diff_result", persisted_diff_result)
    {:noreply, socket}
  end

  defp authorized(%{users: []}, _), do: true

  defp authorized(project, user_id) do
    with %{} = user <- Enum.find(project.users, fn u -> u.id == user_id end),
         %{} = sub <- Payments.load_subscription(user).subscription do
      case sub.status do
        :active ->
          true

        :cancelled ->
          if Payments.cancellation_effective_date(sub) do
            {:ok, effective_date} = Date.from_iso8601(Payments.cancellation_effective_date(sub))
            Date.compare(Date.utc_today(), effective_date) == :lt
          else
            false
          end

        :unknown ->
          false
      end
    else
      _ ->
        false
    end
  end

  defp inspect_time_from(t, label) do
    tnow = :os.system_time(:millisecond)
    IO.inspect("#{tnow - t}ms", label: label)
    tnow
  end

  # You will know it when you want it
  # def terminate({_, trace}, _socket) do
  #   IO.inspect(trace, label: "terminate trace")
  # end
end
