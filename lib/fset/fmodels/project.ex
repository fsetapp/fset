defmodule Fset.Fmodels.Project do
  use Ecto.Schema

  schema "projects" do
    field :anchor, Ecto.UUID
    field :key, :string
    field :order, {:array, :string}
    field :description, :string
    field :current_file_id, :integer, virtual: true

    has_many :files, Fset.Fmodels.File
  end
end
