# codegen: do not edit
defmodule GenLSP.Structures.ChangeAnnotation do
  @moduledoc """
  Additional information that describes document changes.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * label: A human-readable string describing the actual change. The string
    is rendered prominent in the user interface.
  * needs_confirmation: A flag which indicates that user confirmation is needed
    before applying the change.
  * description: A human-readable string which is rendered less prominent in
    the user interface.
  """

  typedstruct do
    field(:label, String.t(), enforce: true)
    field(:needs_confirmation, boolean())
    field(:description, String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"label", :label} => str(),
      optional({"needsConfirmation", :needs_confirmation}) => bool(),
      optional({"description", :description}) => str()
    })
  end
end
