defmodule Fset.Exports.JschDocs do
  use FsetWeb, :view
  use Fset.JSONSchema.Vocab
  use Fset.Fmodels.Vocab

  def gen(projectname) do
    {:ok, project} = Fset.Projects.get_project(projectname)
    project_sch = Fset.Fmodels.to_project_sch(project)
    sch_metas = Fset.Projects.sch_metas_map(project)

    opts = [{:sch_metas, sch_metas} | []]
    schema = Fset.Exports.JSONSchema.json_schema(:one_way, project_sch, opts)
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
          def = Map.get(defs, "#{filename}#{delimeter}#{fmodelname}", %{})

          file = Map.put(file, "taggedLevel", %{1 => fmodelname})
          fmodel = Map.put(fmodel, "export", def)

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
    |> render_html()

    # |> write_file("_export_jsch.term")
  end

  def render_html(project_sch) do
    project_sch
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
