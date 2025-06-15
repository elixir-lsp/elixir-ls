# codegen: do not edit
defmodule GenLSP.Structures.ExecutionSummary do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * execution_order: A strict monotonically increasing value
    indicating the execution order of a cell
    inside a notebook.
  * success: Whether the execution was successful or
    not if known by the client.
  """

  typedstruct do
    field(:execution_order, GenLSP.BaseTypes.uinteger(), enforce: true)
    field(:success, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"executionOrder", :execution_order} => int(),
      optional({"success", :success}) => bool()
    })
  end
end
