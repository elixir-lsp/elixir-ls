# codegen: do not edit
defmodule GenDAP.Structures.SetExpressionArguments do
  @moduledoc """
  Arguments for `setExpression` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * value: The value expression to assign to the l-value expression.
  * format: Specifies how the resulting value should be formatted.
  * frame_id: Evaluate the expressions in the scope of this stack frame. If not specified, the expressions are evaluated in the global scope.
  * expression: The l-value expression to assign to.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :value, String.t(), enforce: true
    field :format, GenDAP.Structures.ValueFormat.t()
    field :frame_id, integer()
    field :expression, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"value", :value} => str(),
      optional({"format", :format}) => GenDAP.Structures.ValueFormat.schematic(),
      optional({"frameId", :frame_id}) => int(),
      {"expression", :expression} => str(),
    })
  end
end
