# codegen: do not edit
defmodule GenDAP.Structures.ExceptionBreakpointsFilter do
  @moduledoc """
  An `ExceptionBreakpointsFilter` is shown in the UI as an filter option for configuring how exceptions are dealt with.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * default: Initial value of the filter option. If not specified a value false is assumed.
  * label: The name of the filter option. This is shown in the UI.
  * description: A help text providing additional information about the exception filter. This string is typically shown as a hover and can be translated.
  * filter: The internal ID of the filter option. This value is passed to the `setExceptionBreakpoints` request.
  * supports_condition: Controls whether a condition can be specified for this filter option. If false or missing, a condition can not be set.
  * condition_description: A help text providing information about the condition. This string is shown as the placeholder text for a text box and can be translated.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :default, boolean()
    field :label, String.t(), enforce: true
    field :description, String.t()
    field :filter, String.t(), enforce: true
    field :supports_condition, boolean()
    field :condition_description, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"default", :default}) => bool(),
      {"label", :label} => str(),
      optional({"description", :description}) => str(),
      {"filter", :filter} => str(),
      optional({"supportsCondition", :supports_condition}) => bool(),
      optional({"conditionDescription", :condition_description}) => str(),
    })
  end
end
