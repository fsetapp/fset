defmodule Fset.Exports.JschDocs do
  use FsetWeb, :view
  use Fset.JSONSchema.Vocab
  use Fset.Fmodels.Vocab

  def gen(_projectname) do
    project = project_fixture()
    project_sch = Fset.Fmodels.to_project_sch(project)
    sch_metas = Fset.Projects.sch_metas_map(project)
    schema_id = "https://localhost/"

    opts = [sch_metas: sch_metas, schema_id: schema_id]
    schema = Fset.Exports.JSONSchema.json_schema(project_sch, opts)
    defs = Map.get(schema, @defs)
    delimeter = opts[:delimeter] || "::"

    anchors_models =
      Enum.reduce(project_sch[@f_fields], %{}, fn %{"key" => k0} = file, acc ->
        file
        |> Map.get(@f_fields)
        |> Map.new(fn %{@f_anchor => a, "key" => k} ->
          {a, %{display: "#{k0}#{delimeter}#{k}"}}
        end)
        |> Map.merge(acc)
      end)

    fmodel_trees =
      Enum.flat_map(project_sch[@f_fields], fn file ->
        {filename, file} = Map.pop!(file, @f_key)

        Enum.map(Map.get(file, @f_fields), fn fmodel ->
          fmodelname = Map.fetch!(fmodel, @f_key)
          doc_module_uri = to_string(URI.merge(URI.parse(schema_id), filename))
          def = get_in(defs, [doc_module_uri, "$defs", fmodelname])

          file = Map.put(file, "taggedLevel", %{1 => fmodelname})
          fmodel = Map.put(fmodel, "export", def)
          fmodel = Map.put(fmodel, "tag", "top")

          {fmodel, _} =
            Fset.Sch.walk(fmodel, %{}, fn a, _m, acc ->
              a = Map.put(a, "metadata", sch_metas[a[@f_anchor]])
              {:cont, {a, acc}}
            end)

          file = Map.put(file, @f_fields, [fmodel])
          _file = Map.put(file, "_models", anchors_models)
        end)
      end)

    fmodel_trees
  end

  defp project_fixture do
    path = Application.app_dir(:fset, "priv/static/fixtures/project-fixture.json")
    fixture = File.read!(path) |> Jason.decode!()

    project_anchor = fixture["$a"]
    project_key = fixture["key"]

    # Extract Fmodels and their Metas from the top-level fields
    fmodels =
      fixture["fields"]
      |> Enum.filter(fn sch ->
        if Map.get(sch, "key", "") in [
             "Record",
             "Tuple",
             "Dict",
             "List",
             "TaggedUnion",
             "UnionOfVal"
           ] do
          true
        else
          false
        end
      end)
      |> Enum.map(fn fmodel_sch ->
        %Fset.Fmodels.Fmodel{
          anchor: fmodel_sch["$a"],
          key: fmodel_sch["key"],
          order: fmodel_sch["index"] || 0,
          is_entry: fmodel_sch["isEntry"] || false,
          sch: Map.drop(fmodel_sch, ["$a", "key", "index", "isEntry"])
        }
      end)

    # Build File
    file = %Fset.Fmodels.File{
      anchor: project_anchor,
      key: project_key,
      t: fixture["t"] || 10,
      order: 0,
      lpath: [],
      fmodels: fmodels
    }

    # Build Project
    %Fset.Projects.Project{
      id: -1,
      anchor: project_anchor,
      key: project_key,
      files: [file],
      sch_metas: []
    }
  end

  def write_file(term, filename) do
    File.write!(Path.expand("../../../assets/static/docs/#{filename}", __DIR__), term)
    |> :erlang.term_to_binary()
  end

  def read_file(filename) do
    File.read!(Path.expand("../../../assets/static/docs/#{filename}", __DIR__))
    |> :erlang.binary_to_term()
  end
end
