defmodule Fset.Imports.JSONSchema do
  use Fset.JSONSchema.Vocab
  alias Fset.JSONSchema.Walker

  @defs_chunk_size 50

  defp chunk_defs_to_files(defs, chunk_size \\ @defs_chunk_size) do
    files =
      defs
      |> Enum.sort_by(fn {key, sch} -> Map.get(sch, "order", key) end)
      |> Enum.chunk_every(chunk_size)
      |> Enum.map(fn [{first, _} | _] = defs_chuck ->
        fmodels =
          %{}
          |> Map.put("type", "object")
          |> Map.put(@properties, Map.new(defs_chuck))
          |> Map.put("order", Enum.map(defs_chuck, fn {key, _} -> key end))

        {first, fmodels}
      end)

    %{}
    |> Map.put("type", "object")
    |> Map.put(@properties, Map.new(files))
    |> Map.put("order", Enum.map(files, fn {key, _} -> key end))
  end

  def json_schema(_version, sch, _opts) do
    defs = Map.get(sch, "$defs") || Map.get(sch, "definitions", %{})
    sch = Map.drop(sch, ["$defs", "definitions"])

    defs =
      Map.new(defs, fn {key, def} ->
        {key, Map.put(def, "$anchor", Ecto.UUID.generate())}
      end)
      |> Map.merge(%{"main" => Map.put(sch, "isEntry", true)})

    sch = chunk_defs_to_files(defs)

    map_put_type = fn
      # %{@type_ => @object} = a, m, acc ->
      #   sch =
      #     %{}
      #     |> Map.put("type", "record")
      #     |> Map.put("fields", Map.get(@properties, %{}))
      #     |> map_put("required", Map.get(a, @required))

      #   {sch, acc}

      %{@properties => props} = a, m, acc ->
        ordered_props = Enum.sort_by(props, fn {key, _sch} -> Map.get(a, "order", key) end)
        keys = Enum.map(ordered_props, fn {key, _} -> key end)

        sch =
          %{}
          |> Map.put("type", "record")
          |> Map.put("fields", props)
          |> Map.put("order", Map.get(a, "order", keys))
          |> map_put("required", Map.get(a, @required))

        {sch, acc}

      %{"items" => item} = a, _m, acc when is_map(item) ->
        sch =
          %{}
          |> Map.put("type", "list")
          |> Map.put("sch", item)

        {sch, acc}

      %{"items" => items} = a, _m, acc when is_list(items) ->
        sch =
          %{}
          |> Map.put("type", "tuple")
          |> Map.put("schs", items)

        {sch, acc}

      %{@prefix_items => items} = a, _m, acc when is_list(items) ->
        sch =
          %{}
          |> Map.put("type", "tuple")
          |> Map.put("schs", items)

        {sch, acc}

      %{@type_ => @string} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "string")

        {sch, acc}

      %{@type_ => @number} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "number")

        {sch, acc}

      %{@type_ => @boolean} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "boolean")

        {sch, acc}

      %{@type_ => @null} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "null")

        {sch, acc}

      %{@const => const} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "value")
          |> Map.put("const", const)

        {sch, acc}

      %{@ref => ref} = a, _m, acc ->
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

        sch =
          %{}
          |> Map.put("type", "ref")
          |> Map.put("$ref", ref)

        {sch, acc}

      %{@any_of => schs} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "union")
          |> Map.put("schs", schs)

        {sch, acc}

      %{@one_of => schs} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "union")
          |> Map.put("schs", schs)

        {sch, acc}

      %{@type_ => types} = a, _m, acc when is_list(types) ->
        schs =
          Enum.map(types, fn
            @object ->
              %{
                "$anchor" => Ecto.UUID.generate(),
                "type" => "record",
                "fields" => %{},
                "order" => []
              }

            @array ->
              %{
                "$anchor" => Ecto.UUID.generate(),
                "type" => "list",
                "sch" => %{"type" => "any", "$anchor" => Ecto.UUID.generate()}
              }

            t when t in [@string, @null, @boolean, @number, @integer] ->
              %{"type" => t, "$anchor" => Ecto.UUID.generate()}

            _t ->
              %{"type" => "any", "$anchor" => Ecto.UUID.generate()}
          end)

        sch =
          %{}
          |> Map.put("type", "union")
          |> Map.put("schs", schs)

        {sch, acc}

      %{} = a, _m, acc ->
        sch =
          %{}
          |> Map.put("type", "any")

        {sch, acc}

      a, _m, acc ->
        {a, acc}
    end

    post_visit = fn a, m, acc ->
      anchor = Map.get(a, @anchor)

      {a_, acc_} = map_put_type.(a, m, acc)

      a_ = Map.put_new(a_, "$anchor", anchor || Ecto.UUID.generate())

      a_ = Map.put_new(a_, "key", Map.get(a, "key"))
      a_ = Map.put_new(a_, "isEntry", Map.get(a, "isEntry"))
      {a_, acc_}
    end

    {schema, _} = Walker.walk(sch, %{}, fn a, _m, acc -> {:cont, {a, acc}} end, post_visit)

    schema
  end

  defp map_put(map, _k, ""), do: map
  defp map_put(map, _k, nil), do: map
  defp map_put(map, _k, []), do: map
  defp map_put(map, k, v), do: Map.put(map, k, v)
end
