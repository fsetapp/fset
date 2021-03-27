defmodule Fset.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :anchor, Ecto.UUID, autogenerate: true
    field :key, :string
    field :order, {:array, :string}
    field :description, :string

    many_to_many :users, Fset.Projects.User, join_through: Fset.Projects.Role

    timestamps()
  end

  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [:key])
    |> unique_constraint(:key)
  end
end
