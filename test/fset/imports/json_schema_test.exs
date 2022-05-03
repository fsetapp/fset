defmodule Fset.ImportsJSONSchemaTest do
  use ExUnit.Case, async: true
  use Fset.Fmodels.Vocab
  alias Fset.Imports.JSONSchema, as: Import

  # def im(map), do: Import.json_schema(:version, map, project_id: 1)

  # describe "extensible record" do
  #     test "ref-to-object + object" do
  #       {p, _acc} =
  #         im(%{
  #           "$defs" => %{"object_a" => %{"type" => "object"}},
  #           "type" => "object",
  #           "$ref" => "#/$defs/object_a"
  #         })

  #       [file_1, file_2] = Map.get(p, @f_fields)
  #       [entry] = Map.get(file_1, @f_fields)
  #       [record_a] = Map.get(file_2, @f_fields)

  #       assert %{@f_type => @f_record} = record_a
  #       assert %{@f_type => @f_e_record} = entry
  #     end

  #     test "ref-to-non-object + object" do
  #       {p, _acc} =
  #         im(%{
  #           "type" => "object",
  #           "$ref" => "#/$defs/object_a"
  #         })

  #       [file_1] = Map.get(p, @f_fields)
  #       [entry] = Map.get(file_1, @f_fields)

  #       assert %{@f_type => @f_tref} = entry
  #     end

  #     test "allOf[ref + object]" do
  #     end
  #   end

  #   describe "enum" do
  #     test "of non-container value" do
  #     end

  #     test "of container value" do
  #     end
  # end
end
