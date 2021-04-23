defmodule Fset.Imports.JSONSchema do
  use Fset.JSONSchema.Vocab
  alias Fset.JSONSchema.Walker

  @defs_chunk_size 50
  @applicators [
    @properties,
    @pattern_properties,
    @items,
    @prefix_items,
    @any_of,
    @one_of
  ]

  defp chunk_defs_to_files(defs, chunk_size \\ @defs_chunk_size) do
    files =
      defs
      |> Enum.sort_by(fn {key, sch} -> Map.get(sch, "order", key) end)
      |> Enum.chunk_every(chunk_size)
      |> Enum.map(fn [{filename, _} | _] = defs_chuck ->
        defs_with_order =
          Map.new(Enum.with_index(defs_chuck), fn {{k, a}, i} ->
            {k, Map.put_new(a, "order", i)}
          end)

        fmodels =
          %{}
          |> Map.put("type", "object")
          |> Map.put(@properties, defs_with_order)

        {filename, fmodels}
      end)

    files_with_order =
      Map.new(Enum.with_index(files), fn {{k, f}, i} -> {k, Map.put_new(f, "order", i)} end)

    %{}
    |> Map.put("type", "object")
    |> Map.put(@properties, files_with_order)
  end

  def json_schema(_version, sch, _opts) do
    defs = Map.get(sch, "$defs") || Map.get(sch, "definitions", %{})

    entry =
      sch
      |> Map.drop(["$defs", "definitions"])
      |> Map.put("isEntry", true)
      |> Map.put("order", 0)

    defs =
      defs
      |> Map.merge(%{"__MAIN__" => entry})
      |> Map.new(fn {key, def} ->
        {key, Map.put_new(def, "$anchor", Ecto.UUID.generate())}
      end)

    sch = chunk_defs_to_files(defs)

    post_visit = fn a, a_og, _m, acc ->
      a_ =
        a
        |> cast_type(defs)
        |> Map.put("$anchor", Map.get(a_og, @anchor) || Ecto.UUID.generate())
        |> map_put("index", Map.get(a_og, "order"))
        |> map_put("key", Map.get(a_og, "key"))
        |> map_put("isEntry", Map.get(a_og, "isEntry"))

      {a_, acc}
    end

    {schema, _} = Walker.walk(sch, %{}, post_visit)
    schema
  end

  defp cast_type(a, defs) do
    case a do
      %{@type_ => @object} -> new_record(a)
      %{@type_ => @array} -> new_list_or_tuple(a)
      %{@type_ => @string} -> new_string(a)
      %{@type_ => @number} -> new_number(a)
      %{@type_ => @integer} -> new_integer(a)
      %{@type_ => @boolean} -> new_boolean(a)
      %{@type_ => @null} -> new_null(a)
      %{@const => _const} -> new_const(a)
      %{@ref => _ref} -> new_ref(a, defs)
      %{@any_of => _schs} -> new_union(a)
      %{@one_of => _schs} -> new_union(a)
      %{@type_ => types} when is_list(types) -> new_union(a, defs)
      a when map_size(a) != 0 -> new_possible_type(a, defs)
      _ -> %{@type_ => "any"}
    end
  end

  defp new_possible_type(a, defs) do
    a = Map.take(a, @applicators)
    a = Map.put(a, @type_, [@object, @array])
    cast_type(a, defs)
  end

  defp new_record(a) do
    ordered_props =
      a
      |> Map.get(@pattern_properties, %{})
      |> Map.new(fn {p_key, sch} -> {p_key, Map.put(sch, "isKeyPattern", true)} end)
      |> Map.merge(Map.get(a, @properties, %{}))
      |> Enum.sort_by(fn {key, sch} -> Map.get(sch, "order", key) end)
      |> Enum.map(fn {key, sch} -> Map.put(sch, "key", key) end)

    %{}
    |> Map.put("type", "record")
    |> Map.put("fields", ordered_props)
    |> map_put("required", Map.get(a, @required))
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
    item = Map.get(a, @items, %{"type" => "any", "$anchor" => Ecto.UUID.generate()})

    %{}
    |> Map.put("type", "list")
    |> Map.put("sch", item)
  end

  defp new_tuple(a) do
    items0 = Map.get(a, @prefix_items, [])
    items1 = Map.get(a, @items, [%{"type" => "any", "$anchor" => Ecto.UUID.generate()}])
    items = items0 ++ items1

    %{}
    |> Map.put("type", "tuple")
    |> Map.put("schs", items)
  end

  defp new_string(a) do
    Map.put(%{}, "type", "string")
  end

  defp new_number(a) do
    Map.put(%{}, "type", "number")
  end

  defp new_integer(a) do
    Map.put(%{}, "type", "integer")
  end

  defp new_boolean(a) do
    Map.put(%{}, "type", "boolean")
  end

  defp new_null(a) do
    Map.put(%{}, "type", "null")
  end

  defp new_const(a) do
    const = Map.get(a, @const)

    %{}
    |> Map.put("type", "value")
    |> Map.put("const", const)
  end

  defp new_ref(%{@ref => ref}, defs) when is_binary(ref) do
    defname =
      case ref do
        "#/$defs/" <> defname -> defname
        "#/definitions/" <> defname -> defname
        defname -> defname
      end

    ref =
      if def = Map.get(defs, defname) do
        Map.get(def, "$anchor")
      else
        ref
      end

    %{}
    |> Map.put("type", "ref")
    |> Map.put("$ref", ref)
  end

  defp new_union(%{@any_of => schs}) when is_list(schs) and length(schs) > 0 do
    %{}
    |> Map.put("type", "union")
    |> Map.put("schs", schs)
  end

  defp new_union(%{@one_of => schs}) when is_list(schs) and length(schs) > 0 do
    %{}
    |> Map.put("type", "union")
    |> Map.put("schs", schs)
  end

  defp new_union(%{@type_ => types} = a, defs) when is_list(types) when length(types) > 0 do
    schs =
      types
      |> Enum.map(fn t -> cast_type(Map.put(a, @type_, t), defs) end)
      |> Enum.map(fn sch -> Map.put_new(sch, "$anchor", Ecto.UUID.generate()) end)

    %{}
    |> Map.put("type", "union")
    |> Map.put("schs", schs)
  end

  defp map_put(map, _k, v) when v in ["", nil, [], false], do: map
  defp map_put(map, k, v), do: Map.put(map, k, v)
end
