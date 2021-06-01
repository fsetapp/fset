defmodule Fset.Sch do
  use Fset.Fmodels.Vocab

  def get(sch, anchor) do
    {_, %{got: got}} =
      walk(sch, %{got: nil}, fn
        %{@f_anchor => ^anchor} = a, m, _acc -> {:halt, {a, %{got: Map.put(a, "meta", m)}}}
        a, _m, acc -> {:cont, {a, acc}}
      end)

    got
  end

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

    fpost.(sch_, meta, acc_)
  end

  defp walk_(sch, f0, f1, acc, meta) do
    case sch do
      %{@f_fields => fields} ->
        fields
        |> Enum.with_index()
        |> Enum.reduce_while({sch, acc}, fn {sch_, i}, {sch_acc, acc_} ->
          k = Map.get(sch_, "key")
          nextMeta = nextMeta(sch_acc, meta, "#{meta["path"]}[#{k}]", i)
          {sch_, acc_} = walk(sch_, acc_, f0, f1, nextMeta)

          sch_acc = put_in(sch_acc, [@f_fields, Access.at!(i)], sch_)
          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      %{@f_schs => schs} ->
        schs
        |> Enum.with_index()
        |> Enum.reduce_while({sch, acc}, fn {sch_, i}, {sch_acc, acc_} ->
          nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][#{i}]", i)
          {sch_, acc_} = walk(sch_, acc_, f0, f1, nextMeta)

          sch_acc = put_in(sch_acc, [@f_schs, Access.at!(i)], sch_)
          if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
        end)

      %{@f_sch => _} ->
        nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][0]", 0)
        {sch_, acc_} = walk(sch[@f_sch], acc, f0, f1, nextMeta)

        sch = put_in(sch[@f_sch], sch_)
        {sch, acc_}

      _ ->
        {sch, acc}
    end
  end

  defp nextMeta(sch, meta, path, i) do
    sch = Map.take(sch, ["tag", @f_type, @f_anchor, "key"])
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
