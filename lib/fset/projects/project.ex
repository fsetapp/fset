defmodule Fset.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :anchor, Ecto.UUID, autogenerate: true
    field :key, :string
    field :description, :string
    field :visibility, Ecto.Enum, values: [:private, :public]

    has_many :sch_metas, Fset.Fmodels.SchMeta

    has_many :files, Fset.Fmodels.File
    many_to_many :users, Fset.Projects.User, join_through: Fset.Projects.Role

    timestamps()
  end

  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [:key, :visibility])
    |> unique_constraint(:key)
  end

  def change_info(project, attrs) do
    info_changeset(project, attrs)
  end

  def apply_info(project, attrs) do
    project
    |> info_changeset(attrs)
    |> Ecto.Changeset.apply_action(:update)
  end

  defp info_changeset(project, attrs) do
    project
    |> cast(attrs, [:key, :description, :visibility])
    |> unique_constraint(:key)
  end
end
