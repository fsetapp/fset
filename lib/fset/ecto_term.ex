defmodule Ecto.Term do
  use Ecto.Type

  def type, do: :map
  def cast(map) when is_map(map), do: {:ok, map}
  def cast(_), do: :error

  def load(""), do: {:ok, %{}}
  def load(bin) when is_binary(bin), do: {:ok, bin |> :erlang.binary_to_term()}
  def load(map) when is_map(map), do: {:ok, map}
  def load(_), do: :error

  def dump(term), do: {:ok, term |> :erlang.term_to_binary()}
end
