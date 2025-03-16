# codegen: do not edit


defmodule GenDAP.Structures.BreakpointMode do
  @moduledoc """
  A `BreakpointMode` is provided as a option when setting breakpoints on sources or instructions.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * applies_to: Describes one or more type of breakpoint this mode applies to.
  * description: A help text providing additional information about the breakpoint mode. This string is typically shown as a hover and can be translated.
  * label: The name of the breakpoint mode. This is shown in the UI.
  * mode: The internal ID of the mode. This value is passed to the `setBreakpoints` request.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure BreakpointMode"
    field :applies_to, list(GenDAP.Enumerations.BreakpointModeApplicability.t()), enforce: true
    field :description, String.t()
    field :label, String.t(), enforce: true
    field :mode, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"appliesTo", :applies_to} => list(GenDAP.Enumerations.BreakpointModeApplicability.schematic()),
      optional({"description", :description}) => str(),
      {"label", :label} => str(),
      {"mode", :mode} => str(),
    })
  end
end

