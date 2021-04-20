defmodule Fset.Fmodels.Fmodel do
  use Ecto.Schema

  schema "fmodels" do
    field :anchor, Ecto.UUID
    field :type, :string
    field :key, :string
    field :sch, Ecto.Term, default: %{}
    field :is_entry, :boolean

    belongs_to :file, Fset.Fmodels.File
  end
end
