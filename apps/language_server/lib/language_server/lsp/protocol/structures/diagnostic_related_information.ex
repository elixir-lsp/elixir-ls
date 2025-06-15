# codegen: do not edit
defmodule GenLSP.Structures.DiagnosticRelatedInformation do
  @moduledoc """
  Represents a related message and source code location for a diagnostic. This should be
  used to point to code locations that cause or related to a diagnostics, e.g when duplicating
  a symbol in a scope.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * location: The location of this related diagnostic information.
  * message: The message of this related diagnostic information.
  """

  typedstruct do
    field(:location, GenLSP.Structures.Location.t(), enforce: true)
    field(:message, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"location", :location} => GenLSP.Structures.Location.schematic(),
      {"message", :message} => str()
    })
  end
end
