defmodule Fset.Fmodels do
  import Ecto.Query, warn: false
  alias Fset.Repo

  alias Fset.Projects.Project
  alias Fset.Fmodels.{File, Fmodel, SchMeta}
  alias Fset.Sch

  use Fset.Fmodels.Vocab

  @project_diff "project"
  @file_diff "files"
  @fmodel_diff "fmodels"

  def persist_metadata(sch, %Project{id: _} = project) do
    to_update_sch_meta = from_sch_meta(sch, project_id: project.id)
    sch_meta_change = Ecto.Changeset.change(%SchMeta{}, to_update_sch_meta)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:update_sch_metas, sch_meta_change,
      conflict_target: [:anchor],
      on_conflict: {:replace, [:title, :description, :metadata]}
    )
    |> Repo.transaction()
    |> (fn {:ok, %{update_sch_metas: sch_meta}} ->
          {:ok,
           sch_meta
           |> Map.from_struct()
           |> Map.take([:anchor, :title, :description, :metadata])}
        end).()
  end

  def prune_sch_metas(project_id, project_sch) do
    {_, sch_metas_anchors} =
      Sch.walk(project_sch, [], fn a, _m, acc_ ->
        {:cont, {a, [Map.get(a, @f_anchor) | acc_]}}
      end)

    delete_sch_meta_query =
      from m in SchMeta,
        where: m.anchor not in ^sch_metas_anchors and m.project_id == ^project_id

    Repo.delete_all(delete_sch_meta_query)
  end

  def persist_diff(diff, %Project{id: _} = project, opts \\ []) do
    {multi, project} =
      {opts[:multi] || Ecto.Multi.new(), project}
      |> update_changed_diff(diff)
      |> delete_removed_diff(diff)
      |> insert_added_diff(diff)

    {Repo.transaction(multi), project}
  end

  # Currently support "type", "key", "order" changes.
  defp update_changed_diff({multi, project}, %{"changed" => changed}) do
    project_attrs =
      changed[@project_diff]
      |> from_project_sch()
      |> Map.put(:updated_at, timestamp())

    files =
      Enum.map(changed[@file_diff] || [], fn {_key, file_sch} ->
        from_file_sch(file_sch)
        |> Map.put(:project_id, project.id)
        |> Map.put(:inserted_at, timestamp())
        |> Map.put(:updated_at, timestamp())
      end)

    fmodels =
      Enum.map(changed[@fmodel_diff] || [], fn {_key, fmodel_sch} ->
        {_, fmodel} = from_fmodel_sch(fmodel_sch, project.id)
        fmodel
      end)
      |> put_required_file_id(project)

    multi =
      multi
      |> Ecto.Multi.update(:update_project, Ecto.Changeset.change(project, project_attrs))
      |> Ecto.Multi.insert_all(:update_files, File, files,
        conflict_target: [:anchor],
        on_conflict: {:replace, [:key, :order]}
      )
      |> Ecto.Multi.insert_all(:update_fmodels, Fmodel, fmodels,
        conflict_target: [:anchor],
        on_conflict: {:replace, [:key, :order, :is_entry, :sch]}
      )

    {multi, project}
  end

  defp insert_added_diff({multi, project}, %{"added" => added}) do
    files =
      Enum.map(added[@file_diff] || [], fn {_key, file_sch} ->
        from_file_sch(file_sch)
        |> Map.put(:project_id, project.id)
        |> Map.put(:inserted_at, timestamp())
        |> Map.put(:updated_at, timestamp())
      end)

    {sch_metas_from_fmodels, ready_fmodels} =
      if added["sch_metas"] do
        fmodels =
          Enum.map(added[@fmodel_diff] || [], fn {_key, fmodel_sch} ->
            {_, fmodel} = from_fmodel_sch(fmodel_sch, project.id)
            fmodel
          end)

        {added["sch_metas"], fmodels}
      else
        Enum.flat_map_reduce(added[@fmodel_diff] || [], [], fn {_key, fmodel_sch}, acc ->
          {sch_metas, fmodel} = from_fmodel_sch(fmodel_sch, project.id)
          {sch_metas, [fmodel | acc]}
        end)
      end

    fmodels_after_files = fn
      %{insert_files: {_n, inserted_files}} ->
        new_files =
          Enum.reduce(inserted_files, project.files, fn file, acc ->
            [
              file
              |> Map.from_struct()
              |> Map.take([:id, :anchor])
              | acc
            ]
          end)

        project = %{project | files: new_files}
        put_required_file_id(ready_fmodels, project)
    end

    multi =
      multi
      |> Ecto.Multi.insert_all(:insert_files, File, files,
        conflict_target: [:anchor],
        on_conflict: {:replace, [:key, :order]},
        returning: true
      )
      |> Ecto.Multi.insert_all(:insert_fmodels, Fmodel, fmodels_after_files,
        conflict_target: [:anchor],
        on_conflict: {:replace, [:key, :order, :is_entry, :sch]},
        returning: true
      )

    multi =
      sch_metas_from_fmodels
      |> Enum.chunk_every(5_000)
      |> Enum.reduce(multi, fn [%{anchor: head} | _] = fmodels_batch, multi_acc ->
        Ecto.Multi.insert_all(multi_acc, {:insert_sch_metas, head}, SchMeta, fmodels_batch,
          conflict_target: [:anchor],
          on_conflict: {:replace, [:title, :description, :metadata]}
        )
      end)

    {multi, project}
  end

  defp delete_removed_diff({multi, project}, %{"removed" => removed}) do
    files_anchors =
      Enum.map(removed[@file_diff] || [], fn {_key, file_sch} ->
        from_file_sch(file_sch).anchor
      end)

    delete_files_query =
      from f in File,
        where: f.project_id == ^project.id and f.anchor in ^files_anchors

    fmodels_anchors =
      Enum.map(removed[@fmodel_diff] || [], fn {_key, fmodel_sch} ->
        Map.get(fmodel_sch, @f_anchor)
      end)

    delete_fmodels_query = from f in Fmodel, where: f.anchor in ^fmodels_anchors, select: f

    delete_sch_metas_query = fn %{delete_fmodels: {_, delete_fmodels}} ->
      sch_metas_anchors =
        Enum.flat_map(delete_fmodels, fn delete_fmodel ->
          sch =
            delete_fmodel.sch
            |> Map.put(@f_anchor, delete_fmodel.anchor)
            |> Map.put("t", delete_fmodel.type)

          {_fmodel_sch, acc} =
            Sch.walk(sch, [], fn a, _m, acc_ ->
              {:cont, {a, [a[@f_anchor] | acc_]}}
            end)

          acc
        end)

      from m in SchMeta,
        where: m.anchor in ^sch_metas_anchors and m.project_id == ^project.id
    end

    multi =
      multi
      |> Ecto.Multi.delete_all(:delete_fmodels, delete_fmodels_query)
      |> Ecto.Multi.delete_all(:delete_sch_metas, delete_sch_metas_query)
      |> Ecto.Multi.delete_all(:delete_files, delete_files_query)

    {multi, project}
  end

  def from_project_sch(nil), do: %{}

  def from_project_sch(project_sch) when is_map(project_sch) do
    %{}
    |> put_from!(:anchor, {project_sch, @f_anchor})
    |> put_from(:description, {project_sch, "description"})
    |> put_from(:key, {project_sch, "key"})
  end

  defp from_file_sch(file_sch) when is_map(file_sch) do
    %{}
    |> put_from!(:anchor, {file_sch, @f_anchor})
    |> put_from(:key, {file_sch, "key"})
    |> put_from(:order, {file_sch, "index"})
  end

  defp from_fmodel_sch(fmodel_sch, project_id) when is_map(fmodel_sch) do
    {sch_metas, sch} = pop_sch_metas(fmodel_sch, project_id: project_id)

    fmodel =
      %{}
      |> put_from!(:anchor, {fmodel_sch, @f_anchor})
      |> put_from(:key, {fmodel_sch, "key"})
      |> put_from(:order, {fmodel_sch, "index"})
      |> Map.put(:is_entry, Map.get(fmodel_sch, "isEntry", false))
      |> Map.put(:sch, sch)

    {sch_metas, fmodel}
  end

  defp pop_sch_metas(fmodel_sch, opts) do
    {sch, sch_meta_acc} =
      Sch.walk(fmodel_sch, [], fn a, _m, acc ->
        acc = [from_sch_meta(a, opts) | acc]
        a = Map.drop(a, ["index", "isEntry", "metadata"])
        {:cont, {a, acc}}
      end)

    {sch_meta_acc, sch}
  end

  def from_sch_meta(sch, opts \\ []) when is_map(sch) do
    metadata = Map.get(sch, "m") || Map.get(sch, "metadata", %{})

    m =
      %{}
      |> put_from(:title, {metadata, "title"})
      |> put_from(:description, {metadata, "description"})
      |> Map.put(:metadata, Map.drop(metadata, ["title", "description"]))
      |> Map.update(:metadata, %{}, fn m ->
        Enum.reduce(m, %{}, fn
          {"rw", "rw"}, acc -> acc
          {"required", false}, acc -> acc
          {k, v}, acc -> Map.put(acc, k, v)
        end)
      end)

    if m != %{} do
      m = put_from!(m, :anchor, {sch, @f_anchor})
      _m = Map.put(m, :project_id, Keyword.fetch!(opts, :project_id))
    else
      m
    end
  end

  defp put_from(map, putkey, {from_map, getkey}, f \\ fn a -> a end) do
    case Map.get(from_map, getkey) do
      nil -> map
      %{"new" => val} -> Map.put(map, putkey, f.(val))
      val -> Map.put(map, putkey, f.(val))
    end
  end

  defp put_from!(map, putkey, {from_map, getkey}, f \\ fn a -> a end) do
    case Map.fetch!(from_map, getkey) do
      %{"new" => val} -> Map.put(map, putkey, f.(val))
      val -> Map.put(map, putkey, f.(val))
    end
  end

  defp timestamp() do
    NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
  end

  # Any fmodel that does not belong to a file will be excluded
  defp put_required_file_id(fmodels, project) when is_list(fmodels) do
    Enum.reduce(fmodels, [], fn fmodel, acc ->
      {fmodel_parent_anchor, sch} = Map.pop(fmodel.sch, "pa")
      fmodel = %{fmodel | sch: sch}

      file = Enum.find(project.files, fn file -> file.anchor == fmodel_parent_anchor end)

      if file do
        fmodel = Map.put(fmodel, :file_id, file.id)
        [fmodel | acc]
      else
        raise "fild_id not found for #{inspect(fmodel)}"
      end
    end)
  end

  def to_project_sch(%Project{} = project, params \\ %{}) do
    %{}
    |> Map.put(@f_anchor, project.anchor)
    |> Map.put("key", project.key)
    |> Map.put("schMetas", [])
    |> Map.put(@f_type, @f_record)
    |> Map.put("fields", Enum.map(project.files, &to_file_sch/1))
    |> map_put_current_file(params)
  end

  defp to_file_sch(%File{} = file) do
    %{}
    |> Map.put(@f_anchor, file.anchor)
    |> Map.put("key", file.key)
    |> Map.put(@f_type, @f_record)
    |> Map.put("fields", Enum.map(file.fmodels, &to_fmodel_sch/1))
  end

  defp to_fmodel_sch(%{anchor: _, key: _} = fmodel) do
    fmodel.sch
    |> Map.put(@f_anchor, fmodel.anchor)
    |> Map.put("key", fmodel.key)
    |> map_put("isEntry", fmodel.is_entry)
  end

  defp map_put_current_file(project_sch, %{"filename" => ""} = params) do
    map_put_current_file(project_sch, Map.delete(params, "filename"))
  end

  defp map_put_current_file(project_sch, params) do
    case project_sch do
      %{"fields" => []} = p ->
        p

      %{"fields" => [file | _]} = p ->
        Map.put(p, "currentFileKey", params["filename"] || Map.get(file, "key"))
    end
  end

  def sch_metas_map(project) do
    project = Repo.preload(project, :sch_metas)

    Enum.reduce(project.sch_metas, %{}, fn m, acc ->
      s =
        %{}
        |> map_put("title", m.title)
        |> map_put("description", m.description)
        |> Map.merge(m.metadata || %{})

      if s == %{}, do: acc, else: Map.put(acc, m.anchor, s)
    end)
  end

  defp map_put(map, _k, v) when v in ["", nil, [], false], do: map
  defp map_put(map, k, v), do: Map.put(map, k, v)
end
