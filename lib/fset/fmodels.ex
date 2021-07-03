defmodule Fset.Fmodels do
  import Ecto.Query, warn: false
  alias Fset.Repo

  alias Fset.Projects.Project
  alias Fset.Fmodels.{File, Fmodel, SchMeta, Referrer}
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

  def cleanup_project_sch(project_id, project_sch) do
    acc = %{anchors: [], referrers: []}

    {_, acc} =
      Sch.walk(project_sch, acc, fn a, _m, acc_ ->
        acc_ =
          if Map.get(a, @f_ref) do
            %{acc_ | referrers: [Map.get(a, @f_anchor) | acc_.referrers]}
          else
            acc_
          end

        acc_ = %{acc_ | anchors: [Map.get(a, @f_anchor) | acc_.anchors]}

        {:cont, {a, acc_}}
      end)

    delete_sch_meta_query =
      from m in SchMeta,
        where: m.anchor not in ^acc.anchors and m.project_id == ^project_id

    delete_referrer_query =
      from r in Referrer,
        where: r.anchor not in ^acc.referrers and r.project_id == ^project_id

    Repo.delete_all(delete_sch_meta_query)
    Repo.delete_all(delete_referrer_query)
  end

  def persist_diff(diff, %Project{id: _} = project, opts \\ []) do
    diff = infer_moved_diff(diff)

    {multi, project} =
      {opts[:multi] || Ecto.Multi.new(), project}
      |> update_changed_diff(diff)
      |> delete_removed_diff(diff)
      |> insert_added_diff(diff)
      |> update_moved_diff(diff)
      |> update_reorder_diff(diff)

    persisted_diff_result = persisted_diff_result(Repo.transaction(multi), project)
    {persisted_diff_result, project}
  end

  defp insert_added_diff({multi, project}, %{"added" => added}) do
    files =
      Enum.map(added[@file_diff] || [], fn {_key, file_sch} ->
        from_file_sch(file_sch)
        |> Map.put(:project_id, project.id)
        |> Map.put(:inserted_at, timestamp())
        |> Map.put(:updated_at, timestamp())
      end)

    %{sch_metas: sch_metas_from_fmodels, fmodels: ready_fmodels, referrers: referrers} =
      if added["sch_metas"] do
        fmodel_acc = reduce_from_fmodel_sch(added[@fmodel_diff], project)
        %{fmodel_acc | sch_metas: added["sch_metas"]}
      else
        reduce_from_fmodel_sch(added[@fmodel_diff], project)
      end

    fmodels_after_files = fn
      %{insert_files: {_n, inserted_files}} ->
        project = collect_file_ids(inserted_files, project)
        put_required_file_id(ready_fmodels, project)
    end

    multi_upsert_referrers_ = fn
      %{insert_fmodels: {_n, inserted_fmodels}} ->
        fmodel_anchor_to_id =
          Enum.reduce(inserted_fmodels, %{}, fn fmodel, acc ->
            Map.put(acc, fmodel.anchor, fmodel.id)
          end)

        multi2 = Ecto.Multi.new()
        multi_upsert_referrers(multi2, :upsert_referrers, referrers, fmodel_anchor_to_id, project)
    end

    multi =
      multi
      |> multi_upsert_files(:insert_files, files)
      |> multi_upsert_fmodels(:insert_fmodels, fmodels_after_files)
      |> multi_upsert_sch_metas(:upsert_sch_metas, sch_metas_from_fmodels)
      |> Ecto.Multi.merge(multi_upsert_referrers_)

    {multi, project}
  end

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

    %{sch_metas: sch_metas_from_fmodels, fmodels: fmodels, referrers: referrers} =
      reduce_from_fmodel_sch(changed[@fmodel_diff], project)

    fmodels = put_required_file_id(fmodels, project)

    fmodel_anchor_to_id =
      Enum.reduce(project.files, %{}, fn file, acc ->
        file.fmodels
        |> Enum.reduce(acc, fn fmodel, acc -> Map.put(acc, fmodel.anchor, fmodel.id) end)
      end)

    multi_upsert_referrers_ = fn %{update_fmodels: {_n, updated_fmodels}} ->
      fmodel_anchor_to_id =
        Enum.reduce(updated_fmodels, fmodel_anchor_to_id, fn fmodel, acc ->
          Map.put(acc, fmodel.anchor, fmodel.id)
        end)

      multi2 = Ecto.Multi.new()
      multi_upsert_referrers(multi2, :upsert_referrers, referrers, fmodel_anchor_to_id, project)
    end

    multi =
      multi
      |> Ecto.Multi.update(:update_project, Ecto.Changeset.change(project, project_attrs))
      |> multi_upsert_files(:update_files, files)
      |> multi_upsert_fmodels(:update_fmodels, fmodels)
      |> multi_upsert_sch_metas(:upsert_sch_metas, sch_metas_from_fmodels)
      |> Ecto.Multi.merge(multi_upsert_referrers_)

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

    delete_fmodels_query =
      from f in Fmodel,
        where: f.anchor in ^fmodels_anchors,
        select: f

    delete_sch_metas_query = fn %{delete_fmodels: {_, delete_fmodels}} ->
      sch_metas_anchors =
        Enum.flat_map(delete_fmodels, fn delete_fmodel ->
          sch =
            delete_fmodel.sch
            |> Map.put(@f_anchor, delete_fmodel.anchor)

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

  defp update_reorder_diff({multi, project}, %{"reorder" => reorder}) do
    files =
      Enum.map(reorder[@file_diff] || [], fn {_key, file_sch} ->
        from_file_sch(file_sch)
        |> Map.put(:project_id, project.id)
        |> Map.put(:inserted_at, timestamp())
        |> Map.put(:updated_at, timestamp())
      end)

    multi =
      multi
      |> multi_upsert_files(:reorder_files, files)
      |> multi_upsert_fmodels_attrs(:reorder_fmodels, reorder[@fmodel_diff], project)

    {multi, project}
  end

  defp infer_moved_diff(%{"removed" => removed, "added" => added} = diff) do
    removing = removed[@fmodel_diff] || %{}
    adding = added[@fmodel_diff] || %{}

    accu = %{adding_acc: adding, deleting_acc: removing, moving_acc: %{}}

    accu =
      for {a_key, a} <- adding, {d_key, d} <- removing, reduce: accu do
        acc ->
          a_anchor = Map.get(a, @f_anchor)
          d_anchor = Map.get(d, @f_anchor)

          if a_anchor == d_anchor do
            a = Map.put(a, "old", d)

            acc = %{acc | adding_acc: Map.delete(acc.adding_acc, a_key)}
            acc = %{acc | deleting_acc: Map.delete(acc.deleting_acc, d_key)}
            _acc = %{acc | moving_acc: Map.put(acc.moving_acc, a_anchor, a)}
          else
            acc
          end
      end

    diff = put_in(diff, ["removed", @fmodel_diff], accu.deleting_acc)
    diff = put_in(diff, ["added", @fmodel_diff], accu.adding_acc)
    _diff = put_in(diff, [Access.key("moved", %{}), @fmodel_diff], accu.moving_acc)
  end

  defp update_moved_diff({multi, project}, %{"moved" => moved}) do
    moving_fmodels = moved[@fmodel_diff]

    multi =
      multi_upsert_fmodels_attrs(multi, :move_fmodels, moving_fmodels, project, [
        :order,
        :key,
        :file_id
      ])

    {multi, project}
  end

  defp multi_upsert_files(multi, key, files) do
    Ecto.Multi.insert_all(multi, key, File, files,
      conflict_target: [:anchor],
      on_conflict: {:replace, [:key, :order]},
      returning: true
    )
  end

  defp multi_upsert_fmodels(multi, key, fmodels) do
    Ecto.Multi.insert_all(multi, key, Fmodel, fmodels,
      conflict_target: [:anchor],
      on_conflict: {:replace, [:key, :order, :is_entry, :sch]},
      returning: true
    )
  end

  defp multi_upsert_sch_metas(multi, key, sch_metas) do
    sch_metas
    |> Enum.chunk_every(5_000)
    |> Enum.reduce(multi, fn [%{anchor: head} | _] = fmodels_batch, multi_acc ->
      Ecto.Multi.insert_all(multi_acc, {key, head}, SchMeta, fmodels_batch,
        conflict_target: [:anchor],
        on_conflict: {:replace, [:title, :description, :metadata]}
      )
    end)
  end

  defp multi_upsert_referrers(multi, key, referrers, refs_lookup, project) do
    referrers
    |> Enum.chunk_every(5_000)
    |> Enum.reduce(multi, fn [{head, _} | _] = referrers_batch, multi_acc ->
      refrers =
        Enum.flat_map(referrers_batch, fn {fmodel_anchor, referrer_list} ->
          Enum.reduce(referrer_list, [], fn referrer_anchor, acc ->
            case Map.fetch(refs_lookup, fmodel_anchor) do
              {:ok, fmodel_id} ->
                [%{fmodel_id: fmodel_id, anchor: referrer_anchor, project_id: project.id} | acc]

              _ ->
                acc
            end
          end)
        end)

      Ecto.Multi.insert_all(multi_acc, {key, head}, Referrer, refrers,
        conflict_target: [:anchor],
        on_conflict: {:replace, [:fmodel_id]}
      )
    end)
  end

  defp multi_upsert_fmodels_attrs(multi, key, fmodels, project, cols \\ [:order, :key]) do
    {anchors, orders, keys, file_ids} =
      Enum.map(fmodels || [], fn {_key, fmodel_sch} ->
        {fmodel, _} = from_fmodel_sch(fmodel_sch, project.id)
        fmodel
      end)
      |> put_required_file_id(project)
      |> Enum.reduce({[], [], [], []}, fn fmodel, {anchor_acc, order_acc, key_acc, file_id_acc} ->
        {:ok, uuid} = Ecto.UUID.dump(fmodel.anchor)
        anchor_acc = [uuid | anchor_acc]
        order_acc = [fmodel.order | order_acc]
        key_acc = [fmodel.key | key_acc]
        file_id_acc = [fmodel.file_id | file_id_acc]
        {anchor_acc, order_acc, key_acc, file_id_acc}
      end)

    replace =
      cols
      |> Enum.map(fn col -> "\"#{col}\" = tmp.#{col}" end)
      |> Enum.intersperse(", ")

    fmodels_attrs_query = ~s"""
      UPDATE fmodels
      SET #{replace}
      FROM
        (SELECT unnest($1::uuid[]) AS anchor,
                unnest($2::integer[]) AS order,
                unnest($3::varchar[]) AS key,
                unnest($4::bigint[]) AS file_id
        ) AS tmp
      WHERE fmodels.anchor = tmp.anchor
      RETURNING tmp.anchor, tmp.file_id, tmp.key, tmp.order, (select file_id from fmodels where anchor = tmp.anchor) as old_file_id, (select sch from fmodels where anchor = tmp.anchor) as sch
    """

    update_fmodels_attrs = fn repo, _ ->
      {:ok, %{rows: rows, num_rows: n, columns: cols}} =
        Ecto.Adapters.SQL.query(repo, fmodels_attrs_query, [anchors, orders, keys, file_ids])

      cols = Enum.map(cols, &String.to_existing_atom/1)

      loaded_fmodels =
        Enum.map(rows, fn row ->
          fmodel = struct(Fmodel, Enum.zip(cols, row))
          {:ok, uuid} = Ecto.UUID.load(fmodel.anchor)
          {:ok, sch} = Ecto.Term.load(fmodel.sch)
          %{fmodel | anchor: uuid, sch: sch}
        end)

      {:ok, {n, loaded_fmodels}}
    end

    Ecto.Multi.run(multi, key, update_fmodels_attrs)
  end

  def persisted_diff_result({:ok, persisted_diff}, project) do
    to_fmodel_sch_with_file_id = fn fmodels ->
      Enum.map(fmodels || [], fn fmodel ->
        Map.put(to_fmodel_sch(fmodel), :file_id, fmodel.file_id)
      end)
    end

    {_, moved_fmodels} = persisted_diff.move_fmodels

    {_, fmodels} = persisted_diff.insert_fmodels
    {_, files} = persisted_diff.insert_files

    fmodels = moved_fmodels ++ fmodels

    project = collect_file_ids(files || [], project)

    added = %{
      "fmodels" => put_file_anchor(to_fmodel_sch_with_file_id.(fmodels), project),
      "files" =>
        Enum.map(files || [], fn f ->
          Map.put(to_file_sch(%{f | fmodels: []}), "pa", project.anchor)
        end)
    }

    {_, fmodels} = persisted_diff.delete_fmodels
    {_, files} = persisted_diff.delete_files

    fmodels =
      Enum.map(moved_fmodels, fn fmodel -> %{fmodel | file_id: fmodel.old_file_id} end) ++ fmodels

    removed = %{
      "fmodels" => put_file_anchor(to_fmodel_sch_with_file_id.(fmodels), project),
      "files" =>
        Enum.map(files || [], fn f ->
          Map.put(to_file_sch(%{f | fmodels: []}), "pa", project.anchor)
        end)
    }

    {_, fmodels} = persisted_diff.update_fmodels
    {_, files} = persisted_diff.update_files

    changed = %{
      "fmodels" => Enum.map(fmodels || [], &to_fmodel_sch/1),
      "files" => Enum.map(files || [], fn f -> to_file_sch(%{f | fmodels: []}) end)
    }

    {_, fmodels} = persisted_diff.reorder_fmodels
    {_, files} = persisted_diff.reorder_files

    reordered = %{
      "fmodels" => put_file_anchor(to_fmodel_sch_with_file_id.(fmodels), project),
      "files" =>
        Enum.map(files || [], fn f ->
          Map.put(to_file_sch(%{f | fmodels: []}), "pa", project.anchor)
        end)
    }

    %{
      "type" => "saved_diff",
      "added" => added,
      "removed" => removed,
      "changed" => changed,
      "reorder" => reordered
    }
  end

  def from_project_sch(nil), do: %{}

  def from_project_sch(project_sch) when is_map(project_sch) do
    %{}
    |> put_from!(:anchor, {project_sch, @f_anchor})
    |> put_from(:description, {project_sch, "description"})
    |> put_from!(:key, {project_sch, @f_key})
  end

  defp from_file_sch(file_sch) when is_map(file_sch) do
    %{}
    |> put_from!(:anchor, {file_sch, @f_anchor})
    |> put_from(:key, {file_sch, @f_key})
    |> put_from(:order, {file_sch, "index"})
  end

  defp from_fmodel_sch(fmodel_sch, project_id, opts \\ []) when is_map(fmodel_sch) do
    {sch, acc} = reduce_fmodel(fmodel_sch, [{:project_id, project_id} | opts])

    fmodel =
      %{}
      |> put_from!(:anchor, {fmodel_sch, @f_anchor})
      |> put_from(:key, {fmodel_sch, @f_key})
      |> put_from(:order, {fmodel_sch, "index"})
      |> Map.put(:is_entry, Map.get(fmodel_sch, "isEntry", false))
      |> Map.put(:sch, %{@f_anchor => _, @f_type => _} = sch)

    {fmodel, acc}
  end

  defp reduce_from_fmodel_sch(nil, project), do: reduce_from_fmodel_sch([], project)

  defp reduce_from_fmodel_sch(fmodels, project) do
    fmodel_acc = %{fmodels: [], sch_metas: [], referrers: %{}}

    Enum.reduce(fmodels, fmodel_acc, fn {_key, fmodel_sch}, acc ->
      {fmodel, fmodel_acc} = from_fmodel_sch(fmodel_sch, project.id)
      acc = %{acc | fmodels: [fmodel | acc.fmodels]}

      acc = %{
        acc
        | referrers: Map.merge(fmodel_acc.referrers, acc.referrers, fn _k, v1, v2 -> v1 ++ v2 end)
      }

      _acc = %{acc | sch_metas: fmodel_acc.sch_metas ++ acc.sch_metas}
    end)
  end

  defp reduce_fmodel(%{@f_ref => r, @f_anchor => r}, _opts),
    do: :error

  defp reduce_fmodel(fmodel_sch, opts) do
    {_sch, _acc} =
      Sch.walk(fmodel_sch, %{sch_metas: [], referrers: %{}}, fn a, _m, acc ->
        sch_meta_acc = [from_sch_meta(a, opts) | acc.sch_metas]
        acc = %{acc | sch_metas: sch_meta_acc}

        acc =
          if ref = Map.get(a, @f_ref) do
            referrer_acc =
              Map.update(acc.referrers, ref, [Map.fetch!(a, @f_anchor)], fn v ->
                [Map.fetch!(a, @f_anchor) | v]
              end)

            %{acc | referrers: referrer_acc}
          else
            acc
          end

        a = Map.drop(a, ["index", "isEntry", "metadata"])
        {:cont, {a, acc}}
      end)
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
      {fmodel_parent_anchor, sch} = Map.pop!(fmodel.sch, "pa")
      fmodel = %{fmodel | sch: sch}

      file = Enum.find(project.files, fn file -> file.anchor == fmodel_parent_anchor end)

      if file do
        fmodel = Map.put(fmodel, :file_id, file.id)
        [fmodel | acc]
      else
        raise "file_id not found for #{inspect(fmodel)}"
      end
    end)
  end

  defp put_file_anchor(fmodels, project) when is_list(fmodels) do
    Enum.reduce(fmodels, [], fn fmodel_sch, acc ->
      {fmodel_file_id, fmodel_sch} = Map.pop(fmodel_sch, :file_id)

      file = Enum.find(project.files, fn file -> file.id == fmodel_file_id end)

      if file do
        fmodel_sch = Map.put(fmodel_sch, "pa", file.anchor)
        [fmodel_sch | acc]
      else
        raise "file_anchor not found for #{inspect(fmodel_sch)}"
      end
    end)
  end

  defp collect_file_ids(new_files, project) do
    new_files =
      Enum.reduce(new_files, project.files, fn file, acc ->
        [
          file
          |> Map.from_struct()
          |> Map.take([:id, :anchor])
          | acc
        ]
      end)

    %{project | files: new_files}
  end

  def to_project_sch(%Project{} = project, params \\ %{}) do
    %{}
    |> Map.put(@f_anchor, project.anchor)
    |> Map.put(@f_key, project.key)
    |> Map.put("schMetas", [])
    |> Map.put(@f_type, @f_record)
    |> Map.put("fields", Enum.map(project.files, &to_file_sch/1))
    |> map_put_current_file(params)
  end

  defp to_file_sch(%File{} = file) do
    %{}
    |> Map.put(@f_anchor, file.anchor)
    |> Map.put(@f_key, file.key)
    |> Map.put("index", file.order)
    |> Map.put(@f_type, @f_record)
    |> Map.put("fields", Enum.map(file.fmodels, &to_fmodel_sch/1))
  end

  defp to_fmodel_sch(%{anchor: _, key: _} = fmodel) do
    fmodel.sch
    |> Map.put(@f_anchor, fmodel.anchor)
    |> Map.put(@f_key, fmodel.key)
    |> Map.put("index", fmodel.order)
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
        Map.put(p, "currentFileKey", params["filename"] || Map.get(file, @f_key))
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

  def referrers_map(project) do
    refers_query =
      from f in Fmodel,
        join: r in assoc(f, :referrers),
        where: r.project_id == ^project.id,
        select: %{referrer: r.anchor, fmodel_anchor: f.anchor}

    referrers = Repo.all(refers_query)

    Enum.group_by(referrers, fn r -> r.fmodel_anchor end, fn r ->
      r.referrer
    end)
  end

  defp map_put(map, _k, v) when v in ["", nil, [], false], do: map
  defp map_put(map, k, v), do: Map.put(map, k, v)
end
