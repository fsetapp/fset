defmodule Fset.Fmodels do
  import Ecto.Query, warn: false
  alias Fset.Repo

  alias Fset.Projects.Project
  alias Fset.Fmodels.{File, Fmodel, SchMeta}
  alias Fset.Sch

  @project_diff "project"
  @file_diff "files"
  @fmodel_diff "fmodels"

  def persist_metadata(sch, %Project{id: _} = project) do
    to_update_sch_meta = Map.put(from_sch_meta(sch), :project_id, project.id)
    sch_meta_change = Ecto.Changeset.change(%SchMeta{}, to_update_sch_meta)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:update_sch_metas, sch_meta_change,
      conflict_target: [:anchor],
      on_conflict: {:replace, [:title, :description, :rw, :required, :metadata]}
    )
    |> Repo.transaction()
    |> (fn {:ok, %{update_sch_metas: sch_meta}} ->
          {:ok,
           sch_meta
           |> Map.from_struct()
           |> Map.take([:anchor, :title, :description, :required, :rw, :metadata])}
        end).()
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
      |> Map.delete(:files)
      |> put_timestamp()

    files =
      Enum.map(changed[@file_diff] || [], fn {_key, file_sch} ->
        from_file_sch(file_sch)
        |> Map.delete(:fmodels)
        |> Map.put(:project_id, project.id)
        |> put_timestamp()
      end)

    fmodels =
      Enum.map(changed[@fmodel_diff] || [], fn {_key, fmodel_sch} -> fmodel_sch end)
      |> Enum.map(fn fmodel_sch -> from_fmodel_sch(fmodel_sch) end)
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
        on_conflict: {:replace, [:key, :order, :type, :is_entry, :sch]}
      )

    {multi, project}
  end

  defp insert_added_diff({multi, project}, %{"added" => added}) do
    files =
      Enum.map(added[@file_diff] || [], fn {_key, file_sch} ->
        from_file_sch(file_sch)
        |> Map.delete(:fmodels)
        |> Map.put(:project_id, project.id)
        |> put_timestamp()
      end)

    ready_fmodels =
      Enum.map(added[@fmodel_diff] || [], fn {_key, fmodel_sch} -> from_fmodel_sch(fmodel_sch) end)

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

    sch_metas_from_fmodels = fn inserted_fmodels ->
      Enum.flat_map(inserted_fmodels, fn inserted_fmodel ->
        sch =
          inserted_fmodel.sch
          |> Map.put("type", inserted_fmodel.type)
          |> Map.put("key", inserted_fmodel.key)
          |> Map.put("$anchor", inserted_fmodel.anchor)
          |> Map.put("isEntry", inserted_fmodel.is_entry)

        {_fmodel_sch, acc} =
          Sch.walk(sch, [], fn a, _m, acc_ ->
            {flat, nest} =
              Map.split(Map.get(a, "metadata", %{}), ["title", "description", "rw", "required"])

            metadata =
              Map.take(nest, [
                "min",
                "max",
                "pattern",
                "default",
                "multipleOf",
                "unique"
              ])

            sch_meta =
              %{}
              |> Map.put(:anchor, a["$anchor"])
              |> Map.put(:title, flat["title"])
              |> Map.put(:description, flat["description"])
              |> Map.put(:rw, String.to_existing_atom(flat["rw"] || "rw"))
              |> Map.put(:required, flat["required"])
              |> Map.put(:metadata, metadata)
              |> Map.put(:project_id, project.id)

            is_non_blank =
              Enum.any?([
                sch_meta.title,
                sch_meta.description,
                sch_meta.required,
                sch_meta.rw != :rw
              ])

            if is_non_blank do
              {:cont, {a, [sch_meta | acc_]}}
            else
              {:cont, {a, acc_}}
            end
          end)

        acc
      end)
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
        on_conflict: {:replace, [:key, :order, :type, :is_entry, :sch]},
        returning: true
      )

    multi =
      sch_metas_from_fmodels.(ready_fmodels)
      |> Enum.chunk_every(5_000)
      |> Enum.reduce(multi, fn [%{anchor: head} | _] = fmodels_batch, multi_acc ->
        Ecto.Multi.insert_all(multi_acc, {:insert_sch_metas, head}, SchMeta, fmodels_batch,
          conflict_target: [:anchor],
          on_conflict: {:replace, [:title, :description, :rw, :required, :metadata]}
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
        from_fmodel_sch(fmodel_sch).anchor
      end)

    delete_fmodels_query = from f in Fmodel, where: f.anchor in ^fmodels_anchors, select: f

    delete_sch_metas_query = fn %{delete_fmodels: {_, delete_fmodels}} ->
      sch_metas_anchors =
        Enum.flat_map(delete_fmodels, fn delete_fmodel ->
          sch =
            delete_fmodel.sch
            |> Map.put("$anchor", delete_fmodel.anchor)
            |> Map.put("type", delete_fmodel.type)

          {_fmodel_sch, acc} =
            Sch.walk(sch, [], fn a, _m, acc_ ->
              {:cont, {a, [a["$anchor"] | acc_]}}
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
    |> put_from!(:anchor, {project_sch, "$anchor"})
    |> put_from(:description, {project_sch, "description"})
    |> put_from(:key, {project_sch, "key"})
    |> put_from(:files, {project_sch, "fields"}, fn fields ->
      Enum.map(fields, &from_file_sch/1)
    end)
  end

  defp from_file_sch({_k, file_sch}), do: from_file_sch(file_sch)

  defp from_file_sch(file_sch) when is_map(file_sch) do
    %{}
    |> put_from!(:anchor, {file_sch, "$anchor"})
    |> put_from(:key, {file_sch, "key"})
    |> put_from(:order, {file_sch, "index"})
    |> put_from(:fmodels, {file_sch, "fields"}, fn fields ->
      Enum.map(fields, &from_fmodel_sch/1)
    end)
  end

  defp from_fmodel_sch({_k, fmodel_sch}), do: from_fmodel_sch(fmodel_sch)

  defp from_fmodel_sch(fmodel_sch) when is_map(fmodel_sch) do
    %{}
    |> put_from!(:anchor, {fmodel_sch, "$anchor"})
    |> put_from(:type, {fmodel_sch, "type"})
    |> put_from(:key, {fmodel_sch, "key"})
    |> put_from(:order, {fmodel_sch, "index"})
    |> Map.put(:is_entry, Map.get(fmodel_sch, "isEntry", false))
    |> Map.put(:sch, Map.drop(fmodel_sch, ["$anchor", "index", "type", "key", "isEntry"]))
  end

  defp from_sch_meta(sch) when is_map(sch) do
    metadata = Map.get(sch, "metadata", %{})

    %{}
    |> put_from!(:anchor, {sch, "$anchor"})
    |> put_from(:title, {metadata, "title"})
    |> put_from(:description, {metadata, "description"})
    |> put_from(:rw, {metadata, "rw"}, fn val -> String.to_atom(val) end)
    |> put_from(:required, {metadata, "required"})
    |> Map.put(:metadata, Map.drop(metadata, ["title", "description", "rw", "required"]))
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

  defp put_timestamp(map) do
    timestamp = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    map
    |> Map.put(:inserted_at, timestamp)
    |> Map.put(:updated_at, timestamp)
  end

  # Any fmodel that does not belong to a file will be excluded
  defp put_required_file_id(fmodels, project) when is_list(fmodels) do
    Enum.reduce(fmodels, [], fn fmodel, acc ->
      {fmodel_parent_anchor, sch} = Map.pop(fmodel.sch, "parentAnchor")
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

  def all_sch_metas(project_id) do
    Repo.all(from m in SchMeta, where: m.project_id == ^project_id)
    |> Enum.reduce(%{}, fn m, acc ->
      Map.put(
        acc,
        m.anchor,
        m
        |> Map.from_struct()
        |> Map.take([:anchor, :title, :description, :required, :rw])
        |> Map.merge(m.metadata)
      )
    end)
  end

  def to_project_sch(%Project{} = project) do
    %{}
    |> Map.put("$anchor", project.anchor)
    |> Map.put("key", project.key)
    |> Map.put("schMetas", project.allmeta)
    |> Map.put("type", "record")
    |> Map.put("fields", Enum.map(project.files, &to_file_sch/1))
    |> (fn
          %{"fields" => []} = p -> p
          %{"fields" => [file | _]} = p -> Map.put(p, "currentFileKey", Map.get(file, "key"))
        end).()
  end

  defp to_file_sch(%File{} = file) do
    %{}
    |> Map.put("$anchor", file.anchor)
    |> Map.put("key", file.key)
    |> Map.put("type", "record")
    |> Map.put("fields", Enum.map(file.fmodels, &to_fmodel_sch/1))
  end

  defp to_fmodel_sch(%Fmodel{} = fmodel) do
    fmodel.sch
    |> Map.put("$anchor", fmodel.anchor)
    |> Map.put("key", fmodel.key)
    |> Map.put("type", fmodel.type)
    |> Map.put("isEntry", fmodel.is_entry)
  end
end
