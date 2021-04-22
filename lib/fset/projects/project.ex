defmodule Fset.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :anchor, Ecto.UUID, autogenerate: true
    field :key, :string
    field :description, :string

    field :current_file_id, :integer, virtual: true
    field :allmeta, :map, virtual: true

    has_many :files, Fset.Fmodels.File
    many_to_many :users, Fset.Projects.User, join_through: Fset.Projects.Role

    timestamps()
  end

  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [:key])
    |> unique_constraint(:key)
  end
end
