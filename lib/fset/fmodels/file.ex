defmodule Fset.Fmodels.File do
  use Ecto.Schema

  schema "files" do
    field :uuid, Ecto.UUID, autogenerate: true
    field :key, :string
    field :order, {:array, :string}

    has_many :fmodels, Fset.Fmodels.Fmodel
    belongs_to :project, Fset.Fmodels.Project

    timestamps()
  end
end
