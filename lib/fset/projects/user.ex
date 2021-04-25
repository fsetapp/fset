defmodule Fset.Projects.User do
  use Ecto.Schema
  alias Fset.Repo

  schema "users" do
    field :email, :string
    field :username, :string
    many_to_many :projects, Fset.Projects.Project, join_through: Fset.Projects.Role

    timestamps()
  end

  @doc """
  Load user projects without project body. Useful for non schema based logic,
  for example listing project names.
  """
  def with_projects(%__MODULE__{} = user), do: Repo.preload(user, :projects)
  def with_projects(%{id: user_id}), do: Repo.preload(%__MODULE__{id: user_id}, :projects)

  def with_projects(username) when is_binary(username) do
    case Repo.get_by(__MODULE__, username: username) do
      nil -> {:error, :not_found}
      user -> {:ok, with_projects(user)}
    end
  end
end
