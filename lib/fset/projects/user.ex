defmodule Fset.Projects.User do
  use Ecto.Schema
  alias Fset.Repo
  import Ecto.Query, warn: false

  schema "users" do
    field :email, :string
    field :username, :string
    field :description, :string
    field :avatar_url, :string
    many_to_many :projects, Fset.Projects.Project, join_through: Fset.Projects.Role

    timestamps()
  end

  @doc """
  Load user projects without project body. Useful for non schema based logic,
  for example listing project names.
  """
  def with_projects(%__MODULE__{} = user),
    do: Repo.preload(user, projects: project_desc_updated())

  def with_projects(%{id: user_id}),
    do: Repo.preload(%__MODULE__{id: user_id}, projects: project_desc_updated())

  def with_projects(username) when is_binary(username) do
    case Repo.get_by(__MODULE__, username: username) do
      nil -> {:error, :not_found}
      user -> {:ok, with_projects(user)}
    end
  end

  defp project_desc_inserted() do
    from(c in Fset.Projects.Project, order_by: [desc: c.inserted_at])
  end

  defp project_desc_updated() do
    from(c in Fset.Projects.Project, order_by: [desc: c.updated_at])
  end
end
