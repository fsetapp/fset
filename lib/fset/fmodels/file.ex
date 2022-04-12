defmodule Fset.Fmodels.File do
  use Ecto.Schema

  schema "files" do
    field :anchor, Ecto.UUID, autogenerate: true
    field :key, :string
    field :order, :integer
    # field :lpath, {:array, :map}

    has_many :fmodels, Fset.Fmodels.Fmodel
    belongs_to :project, Fset.Projects.Project

    timestamps()
  end
end
