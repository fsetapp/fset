defmodule Fset.JSONSchema.Walker do
  use Fset.JSONSchema.Vocab

  def walk(
        sch,
        acc,
        fpost,
        fpre \\ fn a, _, c -> {:cont, {a, c}} end,
        meta \\ %{"path" => "", "level" => 1, "parent" => %{}, "index" => 0}
      )

  def walk(true, acc, fpost, fpre, meta),
    do: walk(%{}, acc, fpost, fpre, meta)

  def walk(false, acc, fpost, fpre, meta),
    do: walk(%{@const => nil}, acc, fpost, fpre, meta)

  def walk(sch, acc, fpost, fpre, meta) do
    {sch_, acc_} =
      case fpre.(Map.delete(sch, :halt), meta, acc) do
        {:halt, {sch_, acc_}} -> {Map.put(sch_, :halt, true), acc_}
        {:cont, {sch_, acc_}} -> walk_(sch_, fpost, fpre, acc_, meta)
      end

    fpost.(sch_, sch, meta, acc_)
  end

  defp walk_(sch, f1, f0, acc, meta) do
    sch
    |> Map.take([
      @properties,
      @pattern_properties,
      @additional_properties,
      @items,
      @prefix_items,
      @one_of,
      @any_of
    ])
    |> Enum.reduce({sch, acc}, fn
      {@properties = box, properties}, {sch_acc, acc_} ->
        walk_keyed(sch_acc, box, properties, f1, f0, acc_, meta)

      {@pattern_properties = box, properties}, {sch_acc, acc_} ->
        walk_keyed(sch_acc, box, properties, f1, f0, acc_, meta)

      {@additional_properties, dict_v}, {sch_acc, acc_} ->
        nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][0]", 0)
        {sch_, acc_} = walk(dict_v, acc_, f1, f0, nextMeta)

        sch_acc = put_in(sch_acc, [@additional_properties], sch_)
        {sch_acc, acc_}

      {@items, item}, {sch_acc, acc_} when is_map(item) ->
        nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][0]", 0)
        {sch_, acc_} = walk(item, acc_, f1, f0, nextMeta)

        sch_acc = put_in(sch_acc, [@items], sch_)
        {sch_acc, acc_}

      {@items = box, items}, {sch_acc, acc_} when is_list(items) ->
        walk_indexed(sch_acc, box, items, f1, f0, acc_, meta)

      {@prefix_items = box, items}, {sch_acc, acc_} when is_list(items) ->
        walk_indexed(sch_acc, box, items, f1, f0, acc_, meta)

      {@one_of = box, schs}, {sch_acc, acc_} ->
        walk_indexed(sch_acc, box, schs, f1, f0, acc_, meta)

      {@any_of = box, schs}, {sch_acc, acc_} ->
        walk_indexed(sch_acc, box, schs, f1, f0, acc_, meta)

      _, {sch_acc, acc_} ->
        {sch_acc, acc_}
    end)
  end

  defp walk_keyed(sch, container, props, f1, f0, acc, meta) when is_map(props) do
    props
    |> Enum.reduce_while({sch, acc}, fn {k, sch_}, {sch_acc, acc_} ->
      sch_ = if sch_ == true, do: %{}, else: sch_
      sch_ = Map.put(sch_, "key", k)
      i = Map.get(sch_, "order")

      nextMeta = nextMeta(sch_acc, meta, "#{meta["path"]}[#{k}]", i)
      {sch_, acc_} = walk(sch_, acc_, f1, f0, nextMeta)

      sch_acc =
        if sch_[:discard],
          do: sch_acc,
          else: put_in(sch_acc, [Access.key(container, %{}), k], sch_)

      if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
    end)
  end

  defp walk_indexed(sch, container, items, f1, f0, acc, meta) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.reduce_while({sch, acc}, fn {sch_, i}, {sch_acc, acc_} ->
      nextMeta = nextMeta(sch, meta, "#{meta["path"]}[][#{i}]", i)
      {sch_, acc_} = walk(sch_, acc_, f1, f0, nextMeta)

      sch_acc =
        if sch_[:discard],
          do: sch_acc,
          else: put_in(sch_acc, [Access.key(container, []), Access.at!(i)], sch_)

      if sch_[:halt], do: {:halt, {sch_acc, acc_}}, else: {:cont, {sch_acc, acc_}}
    end)
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
