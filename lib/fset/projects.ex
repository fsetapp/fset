defmodule Fset.Projects do
  import Ecto.Query, warn: false
  alias Fset.Repo
  alias Fset.Projects.{Project, Role}
  alias Fset.Exports
  alias Fset.Imports

  defdelegate persist_metadata(sch, project), to: Fset.Fmodels
  defdelegate persist_diff(diff, project), to: Fset.Fmodels
  defdelegate to_project_sch(project, params \\ %{}), to: Fset.Fmodels
  defdelegate cleanup_project_sch(project_sch, project_id), to: Fset.Fmodels
  defdelegate sch_metas_map(project), to: Fset.Fmodels
  defdelegate referrers_map(project), to: Fset.Fmodels

  defdelegate change_info(project, attrs \\ %{}), to: Fset.Projects.Project
  defdelegate apply_info(project, attrs \\ %{}), to: Fset.Projects.Project

  def add_member(project_id, user_id, opts \\ []) do
    attrs = %{user_id: user_id, project_id: project_id, role: opts[:role] || :admin}
    changeset = Role.changeset(%Role{}, attrs)

    case Repo.insert(changeset) do
      {:ok, assoc} -> assoc
      {:error, changeset} -> changeset
    end
  end

  def get_head(name) do
    case Repo.one(from p in Project, where: p.key == ^name, preload: [:users]) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  def get_project(name, opts \\ []) do
    sorted_files = from f in Fset.Fmodels.File, order_by: f.order
    sorted_fmodels = from f in Fset.Fmodels.Fmodel, order_by: f.order

    preload = opts[:preload] || [:users, files: {sorted_files, [fmodels: sorted_fmodels]}]

    project_query =
      from p in Project,
        where: p.key == ^name,
        preload: ^preload

    case Repo.one(project_query) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  def get_user_project(name, user_id) do
    project_query =
      from p in Project,
        join: r in Role,
        where: p.id == r.project_id and r.user_id == ^user_id,
        where: p.key == ^name,
        preload: [:users, :sch_metas, files: :fmodels]

    case Repo.one(project_query) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  def create(params \\ %{}) do
    params = Map.put_new(params, :key, "project_#{rand_key(8)}")

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

  def update_info(project, project_params) do
    project
    |> Project.change_info(project_params)
    |> Repo.update()
  end

  def replace(project, schema, acc) do
    # Repo.get_by!(Fset.Projects.Project, key: projectname)
    project_files = from f in Fset.Fmodels.File, where: f.project_id == ^project.id
    project_sch_metas = from m in Fset.Fmodels.SchMeta, where: m.project_id == ^project.id
    project_referreres = from r in Fset.Fmodels.Referrer, where: r.project_id == ^project.id

    multi = Ecto.Multi.new()
    multi = Ecto.Multi.delete_all(multi, :replace_referrers, project_referreres)

    multi =
      Ecto.Multi.delete_all(multi, :replace_files, fn %{replace_referrers: {_n, _refrers}} ->
        project_files
      end)

    multi = Ecto.Multi.delete_all(multi, :replace_sch_metas, project_sch_metas)

    schema = Map.put(schema, "key", project.key)
    Fset.Fmodels.persist_diff(to_diff(schema, acc), build_ids(project), multi: multi)
  end

  defp build_ids(project) do
    map_fmodel = fn m ->
      m
      |> Map.from_struct()
      |> Map.take([:id, :anchor])
    end

    map_file = fn f ->
      f
      |> Map.from_struct()
      |> Map.take([:id, :anchor])
      |> Map.put(:fmodels, Enum.map(f.fmodels, map_fmodel))
    end

    _project = %{project | files: Enum.map(project.files, map_file)}
  end

  defp to_diff(schema, acc) do
    {files, project} = Map.pop!(schema, "fields")

    diff = %{
      "changed" => %{"project" => project},
      "added" => %{},
      "removed" => %{},
      "reorder" => %{}
    }

    diff =
      put_in(
        diff,
        ["added", "files"],
        Enum.reduce(files, %{}, fn file, acc ->
          Map.put(acc, Map.get(file, "key"), file)
        end)
      )

    diff = put_in(diff, ["added", "sch_metas"], Map.get(acc, "metadata_acc"))

    for file <- files, reduce: diff do
      acc ->
        {fmodels, file_} = Map.pop!(file, "fields")

        fmodels =
          Enum.map(fmodels, fn fmodel ->
            fmodel = Map.put(fmodel, "pa", Map.get(file_, "$a"))
            {Map.get(file_, "key") <> Map.get(fmodel, "key"), fmodel}
          end)

        update_in(acc, ["added", Access.key("fmodels", %{})], fn fs ->
          Map.merge(fs, Map.new(fmodels))
        end)
    end
  end

  def export_as_binary(params, opts \\ [])

  def export_as_binary(%{"projectname" => projectname} = params, opts) do
    %{"username" => username, "export" => export} = params
    {:ok, project} = get_project(projectname)

    uri = Map.get(export, "uri", "https://json-schema.fset.app")
    uri = String.trim_trailing(uri, "/")

    path =
      case export do
        %{"project" => "true", "account" => "true"} -> [username, projectname]
        %{"account" => "true"} -> [username]
        %{"project" => "true"} -> [projectname]
        _ -> []
      end

    schema_id = Path.join([uri | path]) <> "/"
    opts = [{:schema_id, schema_id} | opts]
    opts = [{:sch_metas, sch_metas_map(project)} | opts]

    schema = Exports.json_schema(Fset.Fmodels.to_project_sch(project), opts)
    Jason.encode!(schema, [{:pretty, true} | opts[:json] || []])
  end

  def export_as_binary(_, _), do: ""

  def import(params, opts \\ [])

  def import(%{"json_schema_file" => json} = params, opts) do
    %{"projectname" => _projectname, "username" => _username} = params
    schema = Imports.json_schema(:draft7, json, opts)
    # replace(project, schema, %{})
  end

  def import(%{"json_schema_url" => url} = params, opts) do
    %{"projectname" => projectname, "username" => _username} = params
    json = fetch_file(url)
    {:ok, project} = get_project(projectname)

    opts = [{:project_id, project.id} | opts]
    {schema, acc} = Imports.json_schema(:draft7, json, opts)
    {_result, project} = replace(project, schema, acc)

    project
  end

  defp fetch_file(url, retry \\ 3)
  defp fetch_file(_url, 0), do: :error

  defp fetch_file(url, retry) do
    case Finch.request(Finch.build(:get, url), FsetHttp) do
      {:ok, result} ->
        Jason.decode!(result.body)

      {:error, %Mint.TransportError{reason: :closed}} ->
        fetch_file(url, retry - 1)
    end
  end

  defp rand_key(length) when is_integer(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end
end
