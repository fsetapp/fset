defmodule Fset.Projects.Role do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects_users" do
    belongs_to :project, Fset.Projects.Project
    belongs_to :user, Fset.Projects.User
    field :role, Ecto.Enum, values: [:admin, :author]
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:role, :project_id, :user_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:user_id)
  end
end
