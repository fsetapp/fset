defmodule Fset.Exports do
  defdelegate json_schema(project_sch, opts), to: Fset.Exports.JSONSchema
end
