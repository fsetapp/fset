defmodule Fset.Fmodels.Fmodel do
  use Ecto.Schema

  schema "fmodels" do
    field :anchor, Ecto.UUID
    field :key, :string
    field :order, :integer
    field :sch, Ecto.Term, default: %{}
    field :is_entry, :boolean

    belongs_to :file, Fset.Fmodels.File
  end
end
