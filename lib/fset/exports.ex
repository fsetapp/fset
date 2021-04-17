defmodule Fset.Exports do
  defdelegate json_schema(type, project_sch, opts), to: Fset.Exports.JSONSchema
end
