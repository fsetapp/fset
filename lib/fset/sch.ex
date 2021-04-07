defmodule Fset.Sch do
  def walk(sch, acc, f, meta \\ %{"path" => "", "level" => 1, "parent" => %{}})

  def walk(sch, acc, f, meta) do
    case f.(Map.delete(sch, :halt), meta, acc) do
      {:halt, {sch_, acc_}} -> {Map.put(sch_, :halt, true), acc_}
      {:cont, {sch_, acc_}} -> walk_(sch_, f, acc_, meta)
    end
  end

  def walk_(sch, f, acc, meta) do
    cond do
      sch["type"] in ["record"] ->
        sch["order"]
        |> Enum.with_index()
        |> Enum.reduce_while({sch, acc}, fn {k, i}, {sch_acc, acc_} ->
          sch_ = sch_acc["fields"][k]

          nextMeta = nextMeta(sch_acc, meta, "#{meta["path"]}[#{k}]", i)
          {sch_, acc_} = walk(sch_, acc_, f, nextMeta)

          sch_ = Map.put(sch_, "key", k)
          sch_acc = put_in(sch_acc["fields"][k], sch_)

          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      sch["type"] in ["tuple", "union"] ->
        sch["schs"]
        |> Enum.with_index()
        |> Enum.reduce_while({sch, acc}, fn {sch_, i}, {sch_acc, acc_} ->
          nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][#{i}]", i)
          {sch_, acc_} = walk(sch_, acc_, f, nextMeta)

          sch_acc = put_in(sch_acc, ["schs", Access.at!(i)], sch_)
          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      sch["type"] in ["list"] ->
        nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][0]", 0)
        {sch_, acc_} = walk(sch["sch"], acc, f, nextMeta)

        sch = put_in(sch["sch"], sch_)
        {sch, acc_}

      true ->
        {sch, acc}
    end
  end

  defp nextMeta(sch, meta, path, i) do
    sch = Map.take(sch, ["tag", "type", "anchor", "key"])
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