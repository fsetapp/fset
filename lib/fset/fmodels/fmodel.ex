defmodule Fset.Fmodels.Fmodel do
  use Ecto.Schema

  schema "fmodels" do
    field :anchor, Ecto.UUID
    field :key, :string
    field :order, :integer
    field :sch, Ecto.Term, default: %{}
    field :is_entry, :boolean

    belongs_to :file, Fset.Fmodels.File
    field :old_file_id, :integer, virtual: true
    has_many :referrers, Fset.Fmodels.Referrer
  end
end
