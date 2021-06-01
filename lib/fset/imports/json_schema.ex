defmodule Fset.Imports.JSONSchema do
  use Fset.JSONSchema.Vocab
  alias Fset.JSONSchema.Walker

  use Fset.Fmodels.Vocab
  alias Fset.Fmodels.New, as: T

  defp chunk_defs_to_files(defs, opts \\ [delimiter: "_", group_n: 2]) do
    d_chars = opts[:delimiter]
    n_chars = opts[:group_n]

    files =
      defs
      |> Enum.group_by(fn {a, _} ->
        k_list = String.split(a, d_chars)

        if Enum.count(k_list) == 1 do
          [String.at(a, 0)]
        else
          String.split(a, d_chars) |> Enum.take(n_chars)
        end
      end)
      |> Enum.map(fn {group, defs_chuck} ->
        filename = Enum.join(group, d_chars)

        defs_with_order =
          defs_chuck
          |> Enum.sort_by(fn {k, a} -> Map.get(a, "order", k) end)
          |> Enum.with_index()
          |> Map.new(fn {{k, a}, i} ->
            k_list = String.split(k, d_chars) |> Enum.slice(n_chars..-1)
            fmodel_name = Enum.join(k_list, d_chars)

            fmodel_name =
              if k_list == [] || fmodel_name == "",
                do: k,
                else: fmodel_name

            {fmodel_name, Map.put(a, "order", i)}
          end)

        fmodels =
          %{}
          |> Map.put(@type_, @object)
          |> Map.put(@properties, defs_with_order)

        {filename, fmodels}
      end)

    files_with_order =
      files
      |> Enum.sort_by(fn {k, f} -> Map.get(f, "order", k) end)
      |> Enum.with_index()
      |> Map.new(fn {{k, f}, i} -> {k, Map.put(f, "order", i)} end)

    %{}
    |> Map.put(@type_, @object)
    |> Map.put(@properties, files_with_order)
  end

  def json_schema(_version, sch, _opts) do
    defs = Map.get(sch, @defs) || Map.get(sch, "definitions", %{})

    entry =
      sch
      |> Map.drop([@defs, "definitions"])
      |> Map.put("isEntry", true)
      |> Map.put("order", 0)

    defs =
      defs
      |> Map.merge(%{"MAIN" => entry})
      |> Map.new(fn {key, def} ->
        {key, Map.put_new(def, @anchor, Ecto.UUID.generate())}
      end)

    sch = chunk_defs_to_files(defs)

    # depth-first transform from leafs back up to root
    post_visit = fn a, a_og, _m, acc ->
      a_ =
        a
        |> cast_type(defs)
        |> T.put_anchor(Map.get(a_og, @anchor))
        |> map_put("index", Map.get(a_og, "order"))
        |> map_put("key", Map.get(a_og, "key"))
        |> map_put("isEntry", Map.get(a_og, "isEntry"))
        |> update_metadata(fn ->
          %{}
          |> map_put("title", Map.get(a_og, @title))
          |> map_put("description", Map.get(a_og, @description))
        end)

      a_ =
        case {Map.get(a_og, @read_only), Map.get(a_og, @write_only)} do
          {true, false} -> put_in(a_, ["metadata", "rw"], "r")
          {false, true} -> put_in(a_, ["metadata", "rw"], "w")
          _ -> a_
        end

      {a_, acc}
    end

    {schema, _} = Walker.walk(sch, _acc = %{}, post_visit)
    schema
  end

  defp cast_type(a, defs) do
    case a do
      %{@ref => ref, @type_ => @object} -> new_e_record(a, ref, defs)
      # Type that does not care @type_ keyword
      %{@ref => ref} -> new_ref(a, ref, defs)
      %{@const => _} -> new_val(a)
      %{@enum => _} -> new_union(a)
      %{@any_of => schs} -> T.union(schs)
      %{@one_of => _} -> new_tagged_union(a, defs)
      #
      %{@type_ => @object} -> new_record_or_dict(a, defs)
      %{@type_ => @array} -> new_list_or_tuple(a)
      %{@type_ => @string} -> new_string(a)
      %{@type_ => @number} -> new_number(a)
      %{@type_ => @integer} -> new_integer(a)
      %{@type_ => @boolean} -> T.boolean()
      %{@type_ => @null} -> T.null()
      %{@type_ => types} when is_list(types) -> new_union(a, defs)
      #
      %{} = a when map_size(a) != 0 -> new_possible_type(a, defs)
      _ -> T.put_anchor(T.any())
    end
  end

  defp new_possible_type(a, defs) do
    object = Map.take(a, [@properties, @pattern_properties, @additional_properties])
    array = Map.take(a, [@items, @prefix_items])

    possible =
      cond do
        object == %{} and array == %{} -> Map.put(a, @type_, [@array, @object])
        object != %{} and array == %{} -> Map.put(a, @type_, @object)
        object == %{} and array != %{} -> Map.put(a, @type_, @array)
        object != %{} and array != %{} -> %{}
      end

    cast_type(possible, defs)
  end

  defp new_record_or_dict(a, defs) do
    case a do
      %{@properties => _} -> new_record(a)
      %{@pattern_properties => _} -> new_record(a)
      %{@additional_properties => _} -> new_dict(a, defs)
      %{} -> new_record(a)
    end
  end

  defp new_record(a) do
    required = Map.get(a, @required, [])

    ordered_props =
      a
      |> Map.get(@pattern_properties, %{})
      |> Map.new(fn {p_key, sch} -> {p_key, Map.put(sch, "isKeyPattern", true)} end)
      |> Map.merge(Map.get(a, @properties, %{}))
      |> Enum.sort_by(fn {key, sch} -> Map.get(sch, "order", key) end)
      |> Enum.map(fn {key, sch} ->
        sch = Map.put(sch, "key", key)
        update_metadata(sch, fn -> map_put(%{}, "required", key in required) end)
      end)

    T.record(ordered_props)
    |> map_put("lax", !!Map.get(a, @unevaluated_properties))
    |> put_metadata(fn ->
      %{}
      |> map_put("min", Map.get(a, @min_properties))
      |> map_put("max", Map.get(a, @max_properties))
    end)
  end

  defp new_list_or_tuple(a) do
    case a do
      %{@items => item} when is_map(item) -> new_list(a)
      %{@items => items} when is_list(items) -> new_tuple(a)
      %{@prefix_items => items} when is_list(items) -> new_tuple(a)
      a -> new_list(a)
    end
  end

  defp new_list(a) do
    item = Map.get(a, @items, T.put_anchor(T.any()))

    metadata =
      %{}
      |> map_put("min", Map.get(a, @min_items, 1))
      |> map_put("max", Map.get(a, @max_items))

    T.list(item) |> Map.put("metadata", metadata)
  end

  defp new_tuple(a) do
    items0 = Map.get(a, @prefix_items, [])
    items1 = Map.get(a, @items, [T.put_anchor(T.any())])
    items = items0 ++ items1

    T.tuple(items)
    |> put_metadata(fn ->
      %{}
      |> map_put("min", Map.get(a, @min_items, Enum.count(items)))
      |> map_put("max", Map.get(a, @max_items))
    end)
  end

  defp new_e_record(a, ref, defs) do
    def_ = get_def(ref, defs)

    case def_ do
      %{@type_ => @object} ->
        T.e_record([
          T.put_anchor(new_ref(a, ref, defs)),
          T.put_anchor(new_record(a))
        ])

      _ ->
        T.put_anchor(T.any())
    end
  end

  defp new_dict(a, _defs) do
    dict_v = Map.get(a, @additional_properties, %{})

    T.dict([
      T.put_anchor(T.string()),
      T.put_anchor(dict_v)
    ])
  end

  defp new_tagged_union(a, _defs) do
    fields =
      a
      |> Map.get(@one_of, [T.record()])
      |> Enum.with_index()
      |> Enum.map(fn {a, i} ->
        a = Map.put(a, "key", "tag_#{i}")
        T.put_anchor(a)
      end)

    T.tagged_union(fields)
  end

  defp new_string(a) do
    T.string()
    |> put_metadata(fn ->
      %{}
      |> map_put("min", Map.get(a, @min_length))
      |> map_put("max", Map.get(a, @max_length))
      |> map_put("pattern", Map.get(a, @pattern))
    end)
  end

  defp new_number(a) do
    T.float64()
    |> put_metadata(fn ->
      %{}
      |> map_put("min", Map.get(a, @minimum))
      |> map_put("max", Map.get(a, @maximum))
      |> map_put("multipleOf", Map.get(a, @multiple_of))
    end)
  end

  defp new_integer(a) do
    T.int32()
    |> put_metadata(fn ->
      %{}
      |> map_put("min", max(Map.get(a, @minimum), -2_147_483_647))
      |> map_put("max", min(Map.get(a, @maximum), 2_147_483_648))
      |> map_put("multipleOf", Map.get(a, @multiple_of))
    end)
  end

  defp new_val(a) do
    T.value(Map.get(a, @const))
  end

  defp new_ref(_, ref, defs) when is_binary(ref) do
    def_ = get_def(ref, defs)
    ref = if def_, do: Map.get(def_, @anchor), else: ref

    T.ref(ref)
  end

  defp get_def(ref, defs) do
    defname =
      case ref do
        "#/$defs/" <> defname -> defname
        "#/definitions/" <> defname -> defname
        defname -> defname
      end

    Map.get(defs, defname)
  end

  defp new_union(%{@enum => enum}) when is_list(enum) and length(enum) > 0 do
    enum
    |> Enum.map(fn e -> T.put_anchor(new_val(%{@const => e})) end)
    |> T.union()
  end

  defp new_union(%{@type_ => types} = a, defs) when is_list(types) when length(types) > 0 do
    schs =
      types
      |> Enum.map(fn t -> cast_type(Map.put(a, @type_, t), defs) end)
      |> Enum.map(fn sch -> T.put_anchor(sch) end)

    T.union(schs)
  end

  defp map_put(map, _k, v) when v in ["", nil, [], false], do: map
  defp map_put(map, k, v), do: Map.put(map, k, v)

  defp put_metadata(map, f) do
    v = f.()
    if v == %{}, do: map, else: map_put(map, "metadata", v)
  end

  defp update_metadata(map, f) do
    v = f.()
    metadata = Map.get(map, "metadata", %{})

    if v == %{} && metadata == %{},
      do: map,
      else: map_put(map, "metadata", Map.merge(metadata, v))
  end
end
