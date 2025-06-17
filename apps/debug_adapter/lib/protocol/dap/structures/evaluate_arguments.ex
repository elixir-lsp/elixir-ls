# codegen: do not edit

defmodule GenDAP.Structures.EvaluateArguments do
  @moduledoc """
  Arguments for `evaluate` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * column: The contextual column where the expression should be evaluated. This may be provided if `line` is also provided.
    
    It is measured in UTF-16 code units and the client capability `columnsStartAt1` determines whether it is 0- or 1-based.
  * context: The context in which the evaluate request is used.
  * expression: The expression to evaluate.
  * format: Specifies details on how to format the result.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsValueFormattingOptions` is true.
  * frame_id: Evaluate the expression in the scope of this stack frame. If not specified, the expression is evaluated in the global scope.
  * line: The contextual line where the expression should be evaluated. In the 'hover' context, this should be set to the start of the expression being hovered.
  * source: The contextual source in which the `line` is found. This must be provided if `line` is provided.
  """

  typedstruct do
    @typedoc "A type defining DAP structure EvaluateArguments"
    field(:column, integer())
    field(:context, String.t())
    field(:expression, String.t(), enforce: true)
    field(:format, GenDAP.Structures.ValueFormat.t())
    field(:frame_id, integer())
    field(:line, integer())
    field(:source, GenDAP.Structures.Source.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"column", :column}) => int(),
      optional({"context", :context}) =>
        oneof(["watch", "repl", "hover", "clipboard", "variables", str()]),
      {"expression", :expression} => str(),
      optional({"format", :format}) => GenDAP.Structures.ValueFormat.schematic(),
      optional({"frameId", :frame_id}) => int(),
      optional({"line", :line}) => int(),
      optional({"source", :source}) => GenDAP.Structures.Source.schematic()
    })
  end
end
