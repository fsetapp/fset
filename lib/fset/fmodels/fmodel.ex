defmodule Fset.Fmodels.Fmodel do
  use Ecto.Schema

  schema "fmodels" do
    field :uuid, Ecto.UUID
    field :type, :string
    field :key, :string
    field :sch, :map
    field :order, {:array, :string}
    field :is_entry, :boolean

    belongs_to :file, Fset.Fmodels.File
  end
end
