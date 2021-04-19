defmodule Fset.Imports do
  defdelegate json_schema(version, file, opts), to: Fset.Imports.JSONSchema
end
