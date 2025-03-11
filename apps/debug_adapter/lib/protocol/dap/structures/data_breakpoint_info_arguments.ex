# codegen: do not edit
defmodule GenDAP.Structures.DataBreakpointInfoArguments do
  @moduledoc """
  Arguments for `dataBreakpointInfo` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * name: The name of the variable's child to obtain data breakpoint information for.
    If `variablesReference` isn't specified, this can be an expression, or an address if `asAddress` is also true.
  * mode: The mode of the desired breakpoint. If defined, this must be one of the `breakpointModes` the debug adapter advertised in its `Capabilities`.
  * bytes: If specified, a debug adapter should return information for the range of memory extending `bytes` number of bytes from the address or variable specified by `name`. Breakpoints set using the resulting data ID should pause on data access anywhere within that range.
    
    Clients may set this property only if the `supportsDataBreakpointBytes` capability is true.
  * variables_reference: Reference to the variable container if the data breakpoint is requested for a child of the container. The `variablesReference` must have been obtained in the current suspended state. See 'Lifetime of Object References' in the Overview section for details.
  * frame_id: When `name` is an expression, evaluate it in the scope of this stack frame. If not specified, the expression is evaluated in the global scope. When `variablesReference` is specified, this property has no effect.
  * as_address: If `true`, the `name` is a memory address and the debugger should interpret it as a decimal value, or hex value if it is prefixed with `0x`.
    
    Clients may set this property only if the `supportsDataBreakpointBytes`
    capability is true.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :name, String.t(), enforce: true
    field :mode, String.t()
    field :bytes, integer()
    field :variables_reference, integer()
    field :frame_id, integer()
    field :as_address, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"name", :name} => str(),
      optional({"mode", :mode}) => str(),
      optional({"bytes", :bytes}) => int(),
      optional({"variablesReference", :variables_reference}) => int(),
      optional({"frameId", :frame_id}) => int(),
      optional({"asAddress", :as_address}) => bool(),
    })
  end
end
