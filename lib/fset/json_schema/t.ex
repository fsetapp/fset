defmodule Fset.JSONSchema.T do
  def record(fields \\ []) do
    %{"type" => "record", "fields" => fields}
  end

  def string() do
    %{"type" => "string"}
  end

  def any() do
    %{"type" => "any"}
  end

  def put_anchor(a) do
    Map.put_new(a, "$anchor", Ecto.UUID.generate())
  end
end
