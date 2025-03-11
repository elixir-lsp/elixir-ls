# codegen: do not edit
defmodule GenDAP.Structures.SetExceptionBreakpointsArguments do
  @moduledoc """
  Arguments for `setExceptionBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * filters: Set of exception filters specified by their ID. The set of all possible exception filters is defined by the `exceptionBreakpointFilters` capability. The `filter` and `filterOptions` sets are additive.
  * filter_options: Set of exception filters and their options. The set of all possible exception filters is defined by the `exceptionBreakpointFilters` capability. This attribute is only honored by a debug adapter if the corresponding capability `supportsExceptionFilterOptions` is true. The `filter` and `filterOptions` sets are additive.
  * exception_options: Configuration options for selected exceptions.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsExceptionOptions` is true.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :filters, list(String.t()), enforce: true
    field :filter_options, list(GenDAP.Structures.ExceptionFilterOptions.t())
    field :exception_options, list(GenDAP.Structures.ExceptionOptions.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"filters", :filters} => list(str()),
      optional({"filterOptions", :filter_options}) => list(GenDAP.Structures.ExceptionFilterOptions.schematic()),
      optional({"exceptionOptions", :exception_options}) => list(GenDAP.Structures.ExceptionOptions.schematic()),
    })
  end
end
