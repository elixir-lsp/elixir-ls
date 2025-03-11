# codegen: do not edit
defmodule GenDAP.Structures.EvaluateArguments do
  @moduledoc """
  Arguments for `evaluate` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * line: The contextual line where the expression should be evaluated. In the 'hover' context, this should be set to the start of the expression being hovered.
  * format: Specifies details on how to format the result.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsValueFormattingOptions` is true.
  * context: The context in which the evaluate request is used.
  * column: The contextual column where the expression should be evaluated. This may be provided if `line` is also provided.
    
    It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * source: The contextual source in which the `line` is found. This must be provided if `line` is provided.
  * frame_id: Evaluate the expression in the scope of this stack frame. If not specified, the expression is evaluated in the global scope.
  * expression: The expression to evaluate.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :line, integer()
    field :format, GenDAP.Structures.ValueFormat.t()
    field :context, String.t()
    field :column, integer()
    field :source, GenDAP.Structures.Source.t()
    field :frame_id, integer()
    field :expression, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"line", :line}) => int(),
      optional({"format", :format}) => GenDAP.Structures.ValueFormat.schematic(),
      optional({"context", :context}) => oneof(["watch", "repl", "hover", "clipboard", "variables"]),
      optional({"column", :column}) => int(),
      optional({"source", :source}) => GenDAP.Structures.Source.schematic(),
      optional({"frameId", :frame_id}) => int(),
      {"expression", :expression} => str(),
    })
  end
end
