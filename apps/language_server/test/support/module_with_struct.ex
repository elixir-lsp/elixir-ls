defmodule ElixirSenseExample.ModuleWithStruct do
  defstruct [:field_1, field_2: 1]
end

defmodule ElixirSenseExample.ModuleWithTypedStruct do
  @type t :: %ElixirSenseExample.ModuleWithTypedStruct{
          typed_field: %ElixirSenseExample.ModuleWithStruct{},
          other: integer
        }
  defstruct [:typed_field, other: 1]
end
