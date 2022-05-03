defmodule Fset.Fmodels.New do
  use Fset.Fmodels.Vocab
  @m "m"
  @model_m 3
  @core_m 1

  defp ctor(map), do: Map.put(map, @m, @model_m)

  def record(fields \\ []), do: ctor(%{@f_type => @f_record, @f_fields => fields})
  def list(sch), do: ctor(%{@f_type => @f_list, @f_sch => sch})
  def e_record(schs), do: ctor(%{@f_type => @f_e_record, @f_schs => schs})
  def tuple(schs), do: ctor(%{@f_type => @f_tuple, @f_schs => schs})
  def dict(schs), do: ctor(%{@f_type => @f_dict, @f_schs => schs})
  def union(schs), do: ctor(%{@f_type => @f_union, @f_schs => schs})

  def tagged_union(fields) do
    ctor(%{})
    |> Map.put(@f_type, @f_tagged_union)
    |> Map.put(@f_fields, fields)
    |> Map.put("keyPrefix", "tag")
    |> Map.put("tagname", "tagname")
    |> Map.put("allowedSchs", [record()])
  end

  def string(), do: ctor(%{@f_type => @f_string})
  def int8(), do: ctor(%{@f_type => @f_int8})
  def uint8(), do: ctor(%{@f_type => @f_uint8})
  def int16(), do: ctor(%{@f_type => @f_int16})
  def uint16(), do: ctor(%{@f_type => @f_uint16})
  def int32(), do: ctor(%{@f_type => @f_int32})
  def uint32(), do: ctor(%{@f_type => @f_uint32})
  def float32(), do: ctor(%{@f_type => @f_float32})
  def float64(), do: ctor(%{@f_type => @f_float64})
  def boolean(), do: ctor(%{@f_type => @f_boolean})
  def null(), do: ctor(%{@f_type => @f_null})
  def any(), do: ctor(%{@f_type => @f_any})
  # def timestamp(), do: ctor(%{@f_type => @f_timestamp})

  def value(v) when is_binary(v) or is_number(v) or is_boolean(v),
    do: ctor(%{@f_type => @f_value, @f_const => v})

  def value(_v), do: ctor(%{@f_type => @f_value, @f_const => nil})

  def ref(r), do: %{@m => @core_m, @f_type => @f_tref, @f_ref => r}
  def put_anchor(a, anchor \\ nil), do: Map.put_new(a, @f_anchor, anchor || Ecto.UUID.generate())
end
