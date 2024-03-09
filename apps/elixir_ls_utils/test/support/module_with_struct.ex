defmodule ElixirLS.Utils.Example.ModuleWithStruct do
  defstruct [:field_1, field_2: 1]
end

defmodule ElixirLS.Utils.Example.ModuleWithTypedStruct do
  @type t :: %ElixirLS.Utils.Example.ModuleWithTypedStruct{
          typed_field: %ElixirLS.Utils.Example.ModuleWithStruct{},
          other: integer
        }
  defstruct [:typed_field, other: 1]
end
