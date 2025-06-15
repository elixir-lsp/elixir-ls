# codegen: do not edit
defmodule GenLSP.Structures.CallHierarchyIncomingCall do
  @moduledoc """
  Represents an incoming call, e.g. a caller of a method or constructor.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * from: The item that makes the call.
  * from_ranges: The ranges at which the calls appear. This is relative to the caller
    denoted by {@link CallHierarchyIncomingCall.from `this.from`}.
  """

  typedstruct do
    field(:from, GenLSP.Structures.CallHierarchyItem.t(), enforce: true)
    field(:from_ranges, list(GenLSP.Structures.Range.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"from", :from} => GenLSP.Structures.CallHierarchyItem.schematic(),
      {"fromRanges", :from_ranges} => list(GenLSP.Structures.Range.schematic())
    })
  end
end
