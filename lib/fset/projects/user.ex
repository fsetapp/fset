defmodule Fset.Projects.User do
  use Ecto.Schema

  schema "users" do
    field :username, :string
    many_to_many :projects, Fset.Projects.Project, join_through: Fset.Projects.Role

    timestamps()
  end
end
