# codegen: do not edit
defmodule GenDAP.Structures.VariablesArguments do
  @moduledoc """
  Arguments for `variables` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * count: The number of variables to return. If count is missing or 0, all variables are returned.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsVariablePaging` is true.
  * start: The index of the first variable to return; if omitted children start at 0.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsVariablePaging` is true.
  * format: Specifies details on how to format the Variable values.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsValueFormattingOptions` is true.
  * filter: Filter to limit the child variables to either named or indexed. If omitted, both types are fetched.
  * variables_reference: The variable for which to retrieve its children. The `variablesReference` must have been obtained in the current suspended state. See 'Lifetime of Object References' in the Overview section for details.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :count, integer()
    field :start, integer()
    field :format, GenDAP.Structures.ValueFormat.t()
    field :filter, String.t()
    field :variables_reference, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"count", :count}) => int(),
      optional({"start", :start}) => int(),
      optional({"format", :format}) => GenDAP.Structures.ValueFormat.schematic(),
      optional({"filter", :filter}) => oneof(["indexed", "named"]),
      {"variablesReference", :variables_reference} => int(),
    })
  end
end
