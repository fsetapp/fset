defmodule Fset.Fmodels.Vocab do
  defmacro __using__([]) do
    quote do
      # key
      @f_type "t"
      @f_anchor "$a"
      @f_ref "$r"
      @f_const "v"
      #
      @f_fields "fields"
      @f_schs "schs"
      @f_sch "sch"

      # val
      @f_record 10
      @f_e_record 11
      @f_dict 12
      @f_list 13
      @f_tuple 14
      @f_union 15
      @f_tagged_union 16
      #
      @f_string 17
      @f_int8 18
      @f_uint8 19
      @f_int16 20
      @f_uint16 21
      @f_int32 22
      @f_uint32 23
      @f_float32 24
      @f_float64 25
      @f_boolean 26
      @f_null 27
      @f_tref 28
      @f_value 29
      @f_any 30
      @f_timestamp 31

      # kind
      @f_integer [@f_int8, @f_int16, @f_int32, @f_uint8, @f_uint16, @f_uint32]
      @f_float [@f_float32, @f_float64]
      @f_number @f_integer ++ @f_float
    end
  end
end
