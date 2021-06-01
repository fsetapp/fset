defmodule Fset.Exports.JSONSchema do
  alias Fset.Sch
  use Fset.JSONSchema.Vocab
  use Fset.Fmodels.Vocab

  def json_schema(export_type, project_sch, opts \\ []) do
    sch_metas = Map.fetch!(project_sch, "schMetas")
    defs_index = defs_index(project_sch)

    get_meta = fn a -> Map.get(sch_metas, Map.fetch!(a, @f_anchor)) end

    pre_visit = fn
      %{@f_type => @f_record} = a, _, c ->
        a = map_put_required(a, sch_metas)
        {:cont, {a, c}}

      a, _, c ->
        {:cont, {a, c}}
    end

    map_put_type = fn
      %{@f_type => @f_record} = a, _m, acc ->
        sch_meta = get_meta.(a)

        fields = Map.fetch!(a, @f_fields)
        fields = Map.new(fields, fn %{"key" => k} = a -> {k, Map.delete(a, "key")} end)

        sch =
          %{}
          |> Map.put(@type_, @object)
          |> Map.put(@properties, fields)
          |> map_put(@required, Map.get(a, @required))

        # optional
        sch =
          if sch_meta do
            sch = map_put(sch, @min_properties, Map.get(sch_meta, "min"))
            _sch = map_put(sch, @max_properties, Map.get(sch_meta, "max"))
          else
            sch
          end

        {sch, acc}

      %{@f_type => @f_list} = a, _m, acc ->
        sch_meta = get_meta.(a)

        sch =
          %{}
          |> Map.put(@type_, @array)
          |> Map.put(@items, Map.fetch!(a, @f_sch))

        # optional
        sch =
          if sch_meta do
            sch = map_put(sch, @min_items, Map.get(sch_meta, "min", 1))
            _sch = map_put(sch, @max_items, Map.get(sch_meta, "max"))
          else
            sch
          end

        {sch, acc}

      %{@f_type => @f_tuple} = a, _m, acc ->
        sch_meta = get_meta.(a)
        items = Map.fetch!(a, @f_schs)

        sch =
          %{}
          |> Map.put(@type_, @array)
          |> Map.put(@prefix_items, items)

        # optional
        sch =
          if sch_meta do
            sch = map_put(sch, @min_items, Map.get(sch_meta, "min", Enum.count(items)))
            _sch = map_put(sch, @max_items, Map.get(sch_meta, "max"))
          else
            sch
          end

        {sch, acc}

      %{@f_type => @f_union} = a, _m, acc ->
        schs = Map.fetch!(a, @f_schs)
        all_string = Enum.all?(schs, fn u -> Map.get(u, @type_) == @string end)

        sch =
          cond do
            all_string -> Map.put(%{}, @enum, Enum.map(schs, fn e -> Map.get(e, @const) end))
            true -> Map.put(%{}, @any_of, schs)
          end

        {sch, acc}

      %{@f_type => @f_string} = a, _m, acc ->
        sch_meta = get_meta.(a)

        sch =
          %{}
          |> Map.put(@type_, @string)

        # optional
        sch =
          if sch_meta do
            sch = map_put(sch, @min_length, Map.get(sch_meta, "min"))
            sch = map_put(sch, @max_length, Map.get(sch_meta, "max"))
            _sch = map_put(sch, @pattern, Map.get(sch_meta, "pattern"))
          else
            sch
          end

        {sch, acc}

      %{@f_type => num} = a, _m, acc when num in @f_number ->
        sch_meta = get_meta.(a)

        num_type = if num in @f_integer, do: @integer, else: @number

        sch =
          %{}
          |> Map.put(@type_, num_type)

        # optional
        sch =
          if sch_meta do
            sch = map_put(sch, @minimum, Map.get(sch_meta, "min"))
            sch = map_put(sch, @maximum, Map.get(sch_meta, "max"))
            _sch = map_put(sch, @multiple_of, Map.get(sch_meta, "multipleOf"))
          else
            sch
          end

        {sch, acc}

      %{@f_type => @f_boolean} = _a, _m, acc ->
        sch =
          %{}
          |> Map.put(@type_, @boolean)

        {sch, acc}

      %{@f_type => @f_null} = _a, _m, acc ->
        sch =
          %{}
          |> Map.put(@type_, @null)

        {sch, acc}

      %{@f_type => @f_any} = _a, _m, acc ->
        sch = %{}

        {sch, acc}

      %{@f_type => @f_tref} = a, _m, acc ->
        fmodel_anchor = Map.fetch!(a, @f_ref)

        %{path: file_dot_fmodel} = Map.get(defs_index, fmodel_anchor, %{path: fmodel_anchor})
        acc = Map.update(acc, :visit_defs, [], fn v -> [fmodel_anchor | v] end)

        ref =
          case export_type do
            :one_way -> "#/$defs/" <> file_dot_fmodel
            :two_way -> "#" <> fmodel_anchor
          end

        sch =
          %{}
          |> Map.put(@ref, ref)

        {sch, acc}

      %{@f_type => @f_value} = a, _m, acc ->
        sch =
          %{}
          |> Map.put(@const, Map.fetch!(a, @f_const))

        {sch, acc}

      %{@f_type => @f_dict} = a, _m, acc ->
        [_dict_k, dict_v] = Map.fetch!(a, @f_schs)

        sch =
          %{}
          |> Map.put(@type_, @object)
          |> Map.put(@additional_properties, dict_v)

        {sch, acc}

      %{@f_type => @f_e_record} = a, _m, acc ->
        [extend, record] = Map.fetch!(a, @f_schs)

        sch =
          record
          |> Map.put(@ref, extend)

        {sch, acc}

      %{@f_type => @f_tagged_union} = a, _m, acc ->
        tagged_things = Map.fetch!(a, @f_fields)

        all_record = Enum.all?(tagged_things, fn thing -> Map.get(thing, @type_) == @object end)

        sch =
          cond do
            all_record ->
              tagged_things =
                Enum.map(tagged_things, fn thing ->
                  {key, thing} = Map.pop!(thing, "key")
                  _thing = put_in(thing, [@properties, Map.fetch!(a, "tagname")], key)
                end)

              Map.put(%{}, @one_of, tagged_things)

            true ->
              unkeyed = Enum.map(tagged_things, fn thing -> Map.delete(thing, "key") end)
              Map.put(%{}, @one_of, unkeyed)
          end

        {sch, acc}

      a, _m, acc ->
        IO.inspect(a, label: "Unrecognized type :: ")
        {%{}, acc}
    end

    post_visit = fn a, m, acc ->
      {a_, acc_} = map_put_type.(a, m, acc)

      a_ = map_put(a_, "key", Map.get(a, "key"))

      a_ =
        case get_meta.(a) do
          nil ->
            a_

          sch_meta ->
            a_ = map_put(a_, @description, Map.get(sch_meta, :description))
            a_ = map_put(a_, @title, Map.get(sch_meta, :title))

            case Map.get(sch_meta, :rw) do
              :r -> Map.put(a_, @read_only, true)
              :w -> Map.put(a_, @write_only, true)
              :rw -> a_
            end
        end

      a_ = map_put(a_, "isEntry", Map.get(a, "isEntry"))

      a_ =
        case export_type do
          :one_way ->
            a_

          :two_way ->
            a_
            |> Map.put("order", Map.fetch!(m, "index"))
            |> Map.put(@anchor, Map.fetch!(a, @f_anchor))
        end

      {a_, acc_}
    end

    {mapped_sch, walk_acc} = Sch.walk(project_sch, %{}, pre_visit, post_visit)

    schema = finalize(mapped_sch, walk_acc, opts)
    Jason.encode!(schema, [{:pretty, true} | opts[:json] || []])
  end

  defp map_put_required(%{@f_fields => fields} = map, sch_metas) when is_list(fields) do
    required =
      Enum.reduce(fields, [], fn %{@f_anchor => anchor, "key" => k}, acc ->
        meta = Map.get(sch_metas, anchor)
        if meta && meta.required, do: [k | acc], else: acc
      end)

    map_put(map, @required, required)
  end

  defp map_put(map, _k, v) when v in ["", nil, [], false], do: map
  defp map_put(map, k, v), do: Map.put(map, k, v)

  defp defs_index(project_sch) do
    {_, lookup} =
      Sch.walk(project_sch, %{}, fn
        %{@f_anchor => anchor} = a, %{"level" => 3, "path" => path}, acc ->
          path =
            path
            |> String.split(:binary.compile_pattern(["[", "][", "]"]), trim: true)
            |> Enum.join(".")

          acc = Map.put(acc, anchor, %{path: path})
          {:cont, {a, acc}}

        a, _, acc ->
          {:cont, {a, acc}}
      end)

    lookup
  end

  defp finalize(project_sch, walk_acc, opts) do
    _defs_anchors = Map.get(walk_acc, :visit_defs, [])
    _tree_shake = opts[:tree_shake]

    defs =
      for {prefix, file} <- Map.fetch!(project_sch, @properties), reduce: %{} do
        acc ->
          for {fmodel_name, fmodel} <- Map.fetch!(file, @properties), reduce: acc do
            acc_ ->
              Map.put(acc_, "#{prefix}::#{fmodel_name}", fmodel)
          end
      end

    {entry, defs} =
      case Enum.split_with(defs, fn {_k, def} -> Map.get(def, "isEntry") end) do
        {[entry | _], defs} -> {entry, defs}
        {[], defs} -> {{"", %{}}, defs}
      end

    {_, entry} = entry
    entry = Map.delete(entry, "isEntry")

    %{}
    |> map_put(@id, Keyword.get(opts, :schema_id))
    |> map_put(@schema, Keyword.get(opts, :schema_url, schema_2020_12()))
    |> Map.put(@defs, Map.new(defs))
    |> Map.merge(entry)
  end

  defp schema_2020_12(), do: "https://json-schema.org/draft/2020-12/schema"
end
