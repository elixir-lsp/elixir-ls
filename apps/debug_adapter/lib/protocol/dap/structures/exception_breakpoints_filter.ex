# codegen: do not edit
defmodule GenDAP.Structures.ExceptionBreakpointsFilter do
  @moduledoc """
  An `ExceptionBreakpointsFilter` is shown in the UI as an filter option for configuring how exceptions are dealt with.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * condition_description: A help text providing information about the condition. This string is shown as the placeholder text for a text box and can be translated.
  * default: Initial value of the filter option. If not specified a value false is assumed.
  * description: A help text providing additional information about the exception filter. This string is typically shown as a hover and can be translated.
  * filter: The internal ID of the filter option. This value is passed to the `setExceptionBreakpoints` request.
  * label: The name of the filter option. This is shown in the UI.
  * supports_condition: Controls whether a condition can be specified for this filter option. If false or missing, a condition can not be set.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ExceptionBreakpointsFilter"
    field :condition_description, String.t()
    field :default, boolean()
    field :description, String.t()
    field :filter, String.t(), enforce: true
    field :label, String.t(), enforce: true
    field :supports_condition, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"conditionDescription", :condition_description}) => str(),
      optional({"default", :default}) => bool(),
      optional({"description", :description}) => str(),
      {"filter", :filter} => str(),
      {"label", :label} => str(),
      optional({"supportsCondition", :supports_condition}) => bool(),
    })
  end
end
