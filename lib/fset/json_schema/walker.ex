defmodule Fset.JSONSchema.Walker do
  def walk(
        sch,
        acc,
        fpre,
        fpost \\ fn a, _, c -> {a, c} end,
        meta \\ %{"path" => "", "level" => 1, "parent" => %{}, "index" => 0}
      )

  def walk(sch, acc, fpre, fpost, meta) do
    {sch_, acc_} =
      case fpre.(Map.delete(sch, :halt), meta, acc) do
        {:halt, {sch_, acc_}} -> {Map.put(sch_, :halt, true), acc_}
        {:cont, {sch_, acc_}} -> walk_(sch_, fpre, fpost, acc_, meta)
      end

    sch_ = Map.put(sch_, "$anchor", Map.get(sch, "$anchor"))
    sch_ = Map.put(sch_, "isEntry", Map.get(sch, "isEntry"))
    fpost.(sch_, meta, acc_)
  end

  defp walk_(sch, f0, f1, acc, meta) do
    case sch do
      %{"properties" => properties} ->
        properties
        |> Enum.reduce_while({%{}, acc}, fn {k, sch_}, {sch_acc, acc_} ->
          sch_ = Map.put(sch_, "key", k)
          i = Map.get(sch_, "order")

          nextMeta = nextMeta(sch_acc, meta, "#{meta["path"]}[#{k}]", i)
          {sch_, acc_} = walk(sch_, acc_, f0, f1, nextMeta)

          sch_acc = put_in(sch_acc, [Access.key("properties", %{}), k], sch_)

          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      %{"type" => "object"} ->
        sch
        |> Map.get("properties", %{})
        |> Enum.reduce_while({%{}, acc}, fn {k, sch_}, {sch_acc, acc_} ->
          sch_ = Map.put(sch_, "key", k)
          i = Map.get(sch_, "order")

          nextMeta = nextMeta(sch_acc, meta, "#{meta["path"]}[#{k}]", i)
          {sch_, acc_} = walk(sch_, acc_, f0, f1, nextMeta)

          sch_acc = put_in(sch_acc, [Access.key("properties", %{}), k], sch_)

          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      %{"items" => item} when is_map(item) ->
        nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][0]", 0)
        {sch_, acc_} = walk(item, acc, f0, f1, nextMeta)

        sch = put_in(sch, ["items"], sch_)
        {sch, acc_}

      %{"type" => "array"} ->
        items = Map.get(sch, "items", nil) || Map.get(sch, "prefixItems", [])

        items
        |> Enum.with_index()
        |> Enum.reduce_while({sch, acc}, fn {sch_, i}, {sch_acc, acc_} ->
          nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][#{i}]", i)
          {sch_, acc_} = walk(sch_, acc_, f0, f1, nextMeta)

          sch_acc = put_in(sch_acc, [Access.key("items", []), Access.at!(i)], sch_)
          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      %{"oneOf" => schs} ->
        items = schs

        items
        |> Enum.with_index()
        |> Enum.reduce_while({sch, acc}, fn {sch_, i}, {sch_acc, acc_} ->
          nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][#{i}]", i)
          {sch_, acc_} = walk(sch_, acc_, f0, f1, nextMeta)

          sch_acc = put_in(sch_acc, [Access.key("oneOf", []), Access.at!(i)], sch_)
          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      %{"anyOf" => schs} ->
        items = schs

        items
        |> Enum.with_index()
        |> Enum.reduce_while({sch, acc}, fn {sch_, i}, {sch_acc, acc_} ->
          nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][#{i}]", i)
          {sch_, acc_} = walk(sch_, acc_, f0, f1, nextMeta)

          sch_acc = put_in(sch_acc, [Access.key("anyOf", []), Access.at!(i)], sch_)
          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      _ ->
        {sch, acc}
    end
  end

  defp nextMeta(sch, meta, path, i) do
    sch = Map.take(sch, ["tag", "type", "$anchor", "key"])
    meta = Map.take(meta, ["path", "level"])
    currentMeta = Map.merge(sch, meta)

    %{
      "path" => path,
      "level" => meta["level"] + 1,
      "index" => i,
      "parent" => currentMeta
    }
  end
end
