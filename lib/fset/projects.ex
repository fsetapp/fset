defmodule Fset.Projects do
  import Ecto.Query, warn: false
  alias Fset.Repo
  alias Fset.Projects.{Project, Role, User}
  alias Fset.Exports
  alias Fset.Imports

  defdelegate persist_metadata(sch, project), to: Fset.Fmodels
  defdelegate persist_diff(diff, project), to: Fset.Fmodels
  defdelegate to_project_sch(project), to: Fset.Fmodels
  defdelegate from_project_sch(project_sch), to: Fset.Fmodels

  def by_user(%User{} = user), do: Repo.preload(user, :projects)
  def by_user(%{id: user_id}), do: Repo.preload(%User{id: user_id}, :projects)

  def by_username(username) do
    case Repo.get_by(User, username: username) do
      nil -> {:error, :not_found}
      user -> {:ok, by_user(user)}
    end
  end

  def add_member(project_key, user_id, opts \\ []) do
    {:ok, project} = get_project(project_key)

    attrs = %{user_id: user_id, project_id: project.id, role: opts[:role] || :admin}
    changeset = Role.changeset(%Role{}, attrs)

    case Repo.insert(changeset) do
      {:ok, assoc} -> assoc
      {:error, changeset} -> changeset
    end
  end

  def get_project(name) do
    project_query =
      from p in Project,
        where: p.key == ^name,
        preload: [:users, files: :fmodels]

    one_with_sch_metas(project_query)
  end

  def get_project(name, user_id) do
    project_query =
      from p in Project,
        join: r in Role,
        where: p.id == r.project_id and r.user_id == ^user_id,
        where: p.key == ^name,
        preload: [:users, files: :fmodels]

    one_with_sch_metas(project_query)
  end

  defp one_with_sch_metas(query) do
    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      project ->
        allmeta = Fset.Fmodels.all_sch_metas(project.id)
        {:ok, %{project | allmeta: allmeta}}
    end
  end

  def create(params \\ %{}) do
    default_key = "project_#{DateTime.to_unix(DateTime.now!("Etc/UTC"))}"
    params = Map.put_new(params, :key, default_key)

    case params do
      %{user_id: user_id} ->
        {:ok, result} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:create_project, Project.create_changeset(%Project{}, params))
          |> Ecto.Multi.insert(:add_member, fn %{create_project: project} ->
            attrs = %{user_id: user_id, project_id: project.id, role: :admin}
            _changeset = Role.changeset(%Role{}, attrs)
          end)
          |> Repo.transaction()

        result.create_project

      _ ->
        Repo.insert!(Project.create_changeset(%Project{}, params))
    end
  end

  def replace(projectname, schema) do
    project = Repo.get_by!(Fset.Projects.Project, key: projectname)
    project_files = from f in Fset.Fmodels.File, where: f.project_id == ^project.id
    project_sch_metas = from m in Fset.Fmodels.SchMeta, where: m.project_id == ^project.id

    multi = Ecto.Multi.delete_all(Ecto.Multi.new(), :replace_files, project_files)
    multi = Ecto.Multi.delete_all(multi, :replace_sch_metas, project_sch_metas)

    schema = Map.put(schema, :key, projectname)
    Fset.Fmodels.persist_diff(to_diff(schema), %{project | files: []}, multi: multi)
  end

  defp to_diff(schema) do
    {files, project} = Map.pop!(schema, "fields")
    diff = %{"changed" => %{"project" => project}, "added" => %{}, "removed" => %{}}

    diff =
      put_in(
        diff,
        ["added", "files"],
        Enum.reduce(files, %{}, fn {k, file}, acc ->
          file = Map.put(file, "key", k)
          Map.put(acc, k, file)
        end)
      )

    for {_, file} <- files, reduce: diff do
      acc ->
        {fmodels, file_} = Map.pop!(file, "fields")

        fmodels =
          Enum.map(fmodels, fn {k, fmodel} ->
            fmodel = Map.put(fmodel, "key", k)
            fmodel = Map.put(fmodel, "parentAnchor", Map.get(file_, "$anchor"))
            {k, fmodel}
          end)

        update_in(acc, ["added", Access.key("fmodels", %{})], fn fs ->
          Map.merge(fs, Map.new(fmodels))
        end)
    end
  end

  def export_as_binary(params, opts \\ [])

  def export_as_binary(%{"projectname" => projectname, "username" => username}, opts) do
    {:ok, project} = get_project(projectname)

    schema_path = Enum.join([username, projectname], "/")
    schema_id = URI.merge("https://json-schema.fset.app", schema_path) |> URI.to_string()
    opts = [{:schema_id, schema_id} | opts]

    Exports.json_schema(:one_way, Fset.Fmodels.to_project_sch(project), opts)
  end

  def export_as_binary(_, _), do: ""

  def import(params, opts \\ [])

  def import(%{"json_schema_file" => json} = params, opts) do
    %{"projectname" => projectname, "username" => _username} = params
    schema = Imports.json_schema(:draft7, json, opts)
    # replace(projectname, schema)
  end

  def import(%{"json_schema_url" => url} = params, opts) do
    %{"projectname" => projectname, "username" => _username} = params
    json = fetch_file(url) |> Jason.decode!()
    schema = Imports.json_schema(:draft7, json, opts)
    replace(projectname, schema)
    {:ok, project} = get_project(projectname)
    project
  end

  defp fetch_file(url) do
    {:ok, result} = Finch.request(Finch.build(:get, url), FsetHttp)
    result.body
  end
end
