defmodule Fset.Projects do
  import Ecto.Query, warn: false
  alias Fset.Repo
  alias Fset.Projects.{Project, Role, User}
  alias Fset.Fmodels

  def by_user(user) do
    Repo.preload(%User{id: user.id}, :projects)
  end

  def add_member(project_id, user_id, opts \\ []) do
    {:ok, project} = get_project(project_id)

    attrs = %{user_id: user_id, project_id: project.id, role: opts[:role] || :admin}
    changeset = Role.changeset(%Role{}, attrs)

    case Repo.insert(changeset) do
      {:ok, assoc} -> assoc
      {:error, changeset} -> changeset
    end
  end

  def get_project(name) do
    project_query =
      case Ecto.UUID.cast(name) do
        {:ok, uuid} ->
          from p in Fmodels.Project,
            where: p.uuid == ^uuid,
            preload: [files: :fmodels]

        :error ->
          from p in Fmodels.Project,
            where: p.key == ^name,
            preload: [files: :fmodels]
      end

    case Repo.one(project_query) do
      nil -> {:error, :not_found}
      project -> {:ok, project_map(project)}
    end
  end

  def create(params \\ %{}) do
    default_key = "project_#{DateTime.to_unix(DateTime.now!("Etc/UTC"))}"
    params = Map.put_new(params, :key, default_key)

    Repo.insert!(Project.create_changeset(%Project{}, params))
  end

  defp project_map(%Fmodels.Project{} = project) do
    project
    |> Map.from_struct()
    |> Map.take([:id, :key, :order])
    |> Map.put(:anchor, project.uuid)
    |> Map.put(:files, Enum.map(project.files, &file_map/1))
  end

  defp file_map(%Fmodels.File{} = file) do
    file
    |> Map.from_struct()
    |> Map.take([:id, :key, :order])
    |> Map.put(:anchor, file.uuid)
    |> Map.put(:fmodels, Enum.map(file.fmodels, &fmodel_map/1))
  end

  defp fmodel_map(%Fmodels.Fmodel{} = fmodel) do
    fmodel
    |> Map.from_struct()
    |> Map.take([:id, :type, :key, :sch, :order, :is_entry])
    |> Map.put(:anchor, fmodel.uuid)
  end
end
