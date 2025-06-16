# codegen: do not edit

defmodule GenDAP.Structures.DataBreakpointInfoArguments do
  @moduledoc """
  Arguments for `dataBreakpointInfo` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * as_address: If `true`, the `name` is a memory address and the debugger should interpret it as a decimal value, or hex value if it is prefixed with `0x`.
    
    Clients may set this property only if the `supportsDataBreakpointBytes`
    capability is true.
  * bytes: If specified, a debug adapter should return information for the range of memory extending `bytes` number of bytes from the address or variable specified by `name`. Breakpoints set using the resulting data ID should pause on data access anywhere within that range.
    
    Clients may set this property only if the `supportsDataBreakpointBytes` capability is true.
  * frame_id: When `name` is an expression, evaluate it in the scope of this stack frame. If not specified, the expression is evaluated in the global scope. When `variablesReference` is specified, this property has no effect.
  * mode: The mode of the desired breakpoint. If defined, this must be one of the `breakpointModes` the debug adapter advertised in its `Capabilities`.
  * name: The name of the variable's child to obtain data breakpoint information for.
    If `variablesReference` isn't specified, this can be an expression, or an address if `asAddress` is also true.
  * variables_reference: Reference to the variable container if the data breakpoint is requested for a child of the container. The `variablesReference` must have been obtained in the current suspended state. See 'Lifetime of Object References' in the Overview section for details.
  """

  typedstruct do
    @typedoc "A type defining DAP structure DataBreakpointInfoArguments"
    field(:as_address, boolean())
    field(:bytes, integer())
    field(:frame_id, integer())
    field(:mode, String.t())
    field(:name, String.t(), enforce: true)
    field(:variables_reference, integer())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"asAddress", :as_address}) => bool(),
      optional({"bytes", :bytes}) => int(),
      optional({"frameId", :frame_id}) => int(),
      optional({"mode", :mode}) => str(),
      {"name", :name} => str(),
      optional({"variablesReference", :variables_reference}) => int()
    })
  end
end
