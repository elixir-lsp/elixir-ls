# codegen: do not edit
defmodule GenLSP.Structures.Moniker do
  @moduledoc """
  Moniker definition to match LSIF 0.5 moniker definition.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * scheme: The scheme of the moniker. For example tsc or .Net
  * identifier: The identifier of the moniker. The value is opaque in LSIF however
    schema owners are allowed to define the structure if they want.
  * unique: The scope in which the moniker is unique
  * kind: The moniker kind if known.
  """

  typedstruct do
    field(:scheme, String.t(), enforce: true)
    field(:identifier, String.t(), enforce: true)
    field(:unique, GenLSP.Enumerations.UniquenessLevel.t(), enforce: true)
    field(:kind, GenLSP.Enumerations.MonikerKind.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"scheme", :scheme} => str(),
      {"identifier", :identifier} => str(),
      {"unique", :unique} => GenLSP.Enumerations.UniquenessLevel.schematic(),
      optional({"kind", :kind}) => GenLSP.Enumerations.MonikerKind.schematic()
    })
  end
end
