# codegen: do not edit


defmodule GenDAP.Structures.SetExceptionBreakpointsArguments do
  @moduledoc """
  Arguments for `setExceptionBreakpoints` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * exception_options: Configuration options for selected exceptions.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsExceptionOptions` is true.
  * filter_options: Set of exception filters and their options. The set of all possible exception filters is defined by the `exceptionBreakpointFilters` capability. This attribute is only honored by a debug adapter if the corresponding capability `supportsExceptionFilterOptions` is true. The `filter` and `filterOptions` sets are additive.
  * filters: Set of exception filters specified by their ID. The set of all possible exception filters is defined by the `exceptionBreakpointFilters` capability. The `filter` and `filterOptions` sets are additive.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure SetExceptionBreakpointsArguments"
    field :exception_options, list(GenDAP.Structures.ExceptionOptions.t())
    field :filter_options, list(GenDAP.Structures.ExceptionFilterOptions.t())
    field :filters, list(String.t()), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"exceptionOptions", :exception_options}) => list(GenDAP.Structures.ExceptionOptions.schematic()),
      optional({"filterOptions", :filter_options}) => list(GenDAP.Structures.ExceptionFilterOptions.schematic()),
      {"filters", :filters} => list(str()),
    })
  end
end

