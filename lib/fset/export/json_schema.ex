defmodule Fset.Exports.JSONSchema do
  alias Fset.Sch
  use Fset.JSONSchema.Vocab
  use Fset.Fmodels.Vocab

  def json_schema(project_sch, opts \\ []) do
    sch_metas = Keyword.fetch!(opts, :sch_metas)
    defs_index = defs_index(project_sch, opts)

    get_meta = fn a -> Map.get(sch_metas, Map.fetch!(a, @f_anchor), %{}) end

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

        sch =
          if Map.get(sch_meta, "strict"),
            do: Map.put(sch, @unevaluated_properties, !Map.get(sch_meta, "strict")),
            else: sch

        {sch, acc}

      %{@f_type => @f_list} = a, _m, acc ->
        sch_meta = get_meta.(a)

        sch =
          %{}
          |> Map.put(@type_, @array)
          |> Map.put(@items, Map.fetch!(a, @f_sch))
          |> map_put(@min_items, Map.get(sch_meta, "min"))
          |> map_put(@max_items, Map.get(sch_meta, "max"))

        {sch, acc}

      %{@f_type => @f_tuple} = a, _m, acc ->
        items = Map.fetch!(a, @f_schs)

        sch =
          %{}
          |> Map.put(@type_, @array)
          |> Map.put(@prefix_items, items)
          |> map_put(@min_items, Enum.count(items))
          |> map_put(@max_items, Enum.count(items))

        {sch, acc}

      %{@f_type => @f_union} = a, _m, acc ->
        sch_metas = get_meta.(a)

        schs = Map.fetch!(a, @f_schs)
        all_scalar = Enum.all?(schs, fn u -> Map.has_key?(u, @const) end)
        as_union = Map.get(sch_metas, "asUnion")

        sch =
          cond do
            all_scalar && !as_union ->
              Map.put(%{}, @enum, Enum.map(schs, fn e -> Map.get(e, @const) end))

            true ->
              Map.put(%{}, @any_of, schs)
          end

        {sch, acc}

      %{@f_type => @f_string} = a, _m, acc ->
        sch_meta = get_meta.(a)

        sch =
          %{}
          |> Map.put(@type_, @string)
          |> map_put(@min_length, Map.get(sch_meta, "min"))
          |> map_put(@max_length, Map.get(sch_meta, "max"))
          |> map_put(@pattern, Map.get(sch_meta, "pattern"))
          |> map_put(@default, Map.get(sch_meta, "default"))
          |> map_put(@format, Map.get(sch_meta, "format"))

        {sch, acc}

      %{@f_type => num} = a, _m, acc when num in @f__number ->
        sch_meta = get_meta.(a)
        uint = fn degree -> Integer.pow(2, degree) end
        int = fn degree -> div(uint.(degree), 2) end

        {num_type, range} =
          case num do
            @f_int8 -> {@integer, %{min: -int.(8), max: int.(8) - 1}}
            @f_int16 -> {@integer, %{min: -int.(16), max: int.(16) - 1}}
            @f_int32 -> {@integer, %{min: -int.(32), max: int.(32) - 1}}
            @f_uint8 -> {@integer, %{min: 0, max: uint.(8) - 1}}
            @f_uint16 -> {@integer, %{min: 0, max: uint.(16) - 1}}
            @f_uint32 -> {@integer, %{min: 0, max: uint.(32) - 1}}
            @f_integer -> {@integer, %{min: nil, max: nil}}
            _ -> {@number, %{min: nil, max: nil}}
          end

        min = range.min || Map.get(sch_meta, "min")
        max = range.max || Map.get(sch_meta, "max")
        default = Map.get(sch_meta, "default")

        bound = fn
          num, nil, nil -> num
          num, min, nil -> max(num, min)
          num, nil, max -> min(num, max)
          num, min, max -> min(max(num, min), max)
        end

        sch =
          %{}
          |> Map.put(@type_, num_type)
          |> map_put(@minimum, min)
          |> map_put(@maximum, max)
          |> map_put(@multiple_of, Map.get(sch_meta, "multipleOf"))
          |> map_put(@default, default && bound.(default, min, max))
          |> map_put(@format, Map.get(sch_meta, "format"))

        {sch, acc}

      %{@f_type => @f_boolean} = a, _m, acc ->
        sch_meta = get_meta.(a)

        sch = Map.put(%{}, @type_, @boolean)

        sch =
          case Map.get(sch_meta, "default") do
            "f" -> Map.put(sch, @default, false)
            "t" -> Map.put(sch, @default, true)
            _ -> sch
          end

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
        %{lpath: [module_uri, defname]} = Map.get(defs_index, fmodel_anchor)
        acc = Map.update(acc, :visit_defs, [], fn v -> [fmodel_anchor | v] end)

        sch = Map.put(%{}, @ref, to_string(URI.merge(module_uri, "#/$defs/" <> defname)))

        {sch, acc}

      %{@f_type => @f_value} = a, _m, acc ->
        sch =
          %{}
          |> Map.put(@const, Map.fetch!(a, @f_const))

        {sch, acc}

      %{@f_type => @f_dict} = a, _m, acc ->
        sch_metas = get_meta.(a)
        [dict_k, dict_v] = Map.fetch!(a, @f_schs)

        sch =
          %{}
          |> Map.put(@type_, @object)
          |> Map.put(@additional_properties, dict_v)
          |> map_put(@min_properties, Map.get(sch_metas, "min"))
          |> map_put(@max_properties, Map.get(sch_metas, "max"))

        sch =
          case dict_k do
            %{@type_ => @string} ->
              map_put(sch, @property_names, dict_k)

            _ ->
              sch
          end

        {sch, acc}

      %{@f_type => @f_e_record} = a, _m, acc ->
        [extend, record] = Map.fetch!(a, @f_schs)

        sch =
          record
          |> Map.put(@ref, Map.get(extend, @ref))

        {sch, acc}

      %{@f_type => @f_tagged_union} = a, _m, acc ->
        tagged_things = Map.fetch!(a, @f_fields)
        sch_meta = get_meta.(a)

        all_record =
          Enum.all?(tagged_things, fn
            %{@type_ => @object} ->
              true

            %{@ref => ref} ->
              Enum.find_value(defs_index, fn
                {_, %{@f_type => @f_record} = t} ->
                  [module_uri, defname] = Map.get(t, :lpath)
                  ref == to_string(URI.merge(module_uri, "#/$defs/" <> defname))

                _t ->
                  false
              end)

            _t ->
              false
          end)

        sch =
          cond do
            all_record ->
              tagged_things =
                Enum.map(tagged_things, fn thing ->
                  {key, thing} = Map.pop!(thing, "key")

                  tagname = Map.fetch!(sch_meta, "tagname")

                  thing =
                    put_in(
                      thing,
                      [Access.key(@properties, %{}), tagname],
                      %{@const => key}
                    )

                  Map.update(thing, @required, [tagname], fn required -> [tagname | required] end)
                end)

              Map.put(%{}, @one_of, tagged_things)

            true ->
              unkeyed = Enum.map(tagged_things, fn thing -> Map.delete(thing, "key") end)
              Map.put(%{}, @one_of, unkeyed)
          end

        sch = Map.put(sch, @unevaluated_properties, false)
        {sch, acc}

      a, _m, acc ->
        acc = Map.update(acc, :unknown, [a], fn unknown -> [a | unknown] end)
        {%{discard: true}, acc}
    end

    post_visit = fn a, m, acc ->
      {a_, acc_} = map_put_type.(a, m, acc)

      a_ = map_put(a_, "key", Map.get(a, "key"))

      a_ =
        case get_meta.(a) do
          nil ->
            a_

          sch_meta ->
            a_ = map_put(a_, @description, Map.get(sch_meta, "description"))
            a_ = map_put(a_, @title, Map.get(sch_meta, "title"))

            case Map.get(sch_meta, "rw") do
              "r" -> Map.put(a_, @read_only, true)
              "w" -> Map.put(a_, @write_only, true)
              _ -> a_
            end
        end

      a_ = map_put(a_, "isEntry", Map.get(a, "isEntry"))

      {a_, acc_}
    end

    {mapped_sch, walk_acc} = Sch.walk(project_sch, %{}, pre_visit, post_visit)
    # IO.inspect(walk_acc)

    _schema = bundle(mapped_sch, walk_acc, opts)
  end

  defp map_put_required(%{@f_fields => fields} = map, sch_metas) when is_list(fields) do
    required =
      Enum.reduce(fields, [], fn %{@f_anchor => anchor, "key" => k}, acc ->
        meta = Map.get(sch_metas, anchor)
        if meta && Map.get(meta, "required"), do: [k | acc], else: acc
      end)

    map_put(map, @required, required)
  end

  defp map_put(map, _k, v) when v in ["", nil, [], false], do: map
  defp map_put(map, k, v), do: Map.put(map, k, v)

  defp defs_index(project_sch, params) do
    schema_id = Keyword.fetch!(params, :schema_id)

    {_, lookup} =
      Sch.walk(project_sch, %{}, fn
        %{@f_anchor => anchor} = a, %{"level" => 3, "path" => path}, acc ->
          [filename | defname] =
            String.split(path, :binary.compile_pattern(["[", "][", "]"]), trim: true)

          module_uri = to_string(URI.merge(schema_id, filename))
          a = Map.put(a, :lpath, [module_uri, Enum.join(defname)])
          acc = Map.put(acc, anchor, a)
          {:cont, {a, acc}}

        a, _, acc ->
          {:cont, {a, acc}}
      end)

    lookup
  end

  defp bundle(project_sch, _walk_acc, opts) do
    schema_id = Keyword.fetch!(opts, :schema_id)

    app =
      project_sch
      |> Map.fetch!(@properties)
      |> Enum.reduce(%{modules: %{}, program: %{}}, fn {filename, file}, acc ->
        module_uri = to_string(URI.merge(schema_id, filename))
        defs = Map.fetch!(file, @properties)

        case build_schmea_file(module_uri, defs) do
          {:definitions, schema} ->
            put_in(acc, [:modules, module_uri], schema)

          {:entrypoint, schema} ->
            acc = put_in(acc, [:modules, module_uri], schema)
            _acc = Map.put(acc, :program, %{@ref => module_uri})
        end
      end)

    Map.merge(app.program, %{
      @id => schema_id,
      @schema => schema_2020_12(),
      @defs => app.modules
    })
  end

  defp build_schmea_file(module_uri, defs) do
    {t, {entry, defs}} =
      case Enum.split_with(defs, fn {_, def_} -> Map.get(def_, "isEntry") end) do
        {[], _} -> {:definitions, {%{}, defs}}
        {[{_, entry}], defs} -> {:entrypoint, {entry, defs}}
      end

    schema =
      entry
      |> Map.delete("isEntry")
      |> Map.put(@id, module_uri)
      |> Map.put(@schema, schema_2020_12())
      |> Map.put(@defs, Map.new(defs, fn {k, def} -> {k, def} end))

    {t, schema}
  end

  defp schema_2020_12, do: "https://json-schema.org/draft/2020-12/schema"
end
