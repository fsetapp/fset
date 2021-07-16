defmodule Fset.JSONSchema.Vocab do
  defmacro __using__([]) do
    quote do
      # https://json-schema.org/specification-links.html#2020-12
      # Vocabs

      # Core
      @id "$id"
      @schema "$schema"
      @ref "$ref"
      @defs "$defs"
      @anchor "$anchor"

      ##
      @object "object"
      @properties "properties"
      @pattern_properties "patternProperties"
      @additional_properties "additionalProperties"
      @unevaluated_properties "unevaluatedProperties"
      @property_names "propertyNames"
      #
      @max_properties "maxProperties"
      @min_properties "minProperties"
      @required "required"

      ##
      @array "array"
      @items "items"
      @prefix_items "prefixItems"
      @unevaluated_items "unevaluatedItems"
      #
      @max_items "maxItems"
      @min_items "minItems"

      ##
      @string "string"
      @min_length "minLength"
      @max_length "maxLength"
      @pattern "pattern"

      ##
      @number "number"
      @multiple_of "multipleOf"
      @maximum "maximum"
      @minimum "minimum"

      ##
      @integer "integer"

      @type_ "type"
      @const "const"
      @enum "enum"
      @boolean "boolean"
      @null "null"

      @any_of "anyOf"
      @one_of "oneOf"

      # Meta-data
      @examples "examples"
      @title "title"
      @description "description"
      @read_only "readOnly"
      @write_only "writeOnly"
      @default "default"
      # Semantic content
      @format "format"
    end
  end
end
