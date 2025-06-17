# codegen: do not edit
defmodule GenLSP.Structures.CallHierarchyOutgoingCall do
  @moduledoc """
  Represents an outgoing call, e.g. calling a getter from a method or a method from a constructor etc.

  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * to: The item that is called.
  * from_ranges: The range at which this item is called. This is the range relative to the caller, e.g the item
    passed to {@link CallHierarchyItemProvider.provideCallHierarchyOutgoingCalls `provideCallHierarchyOutgoingCalls`}
    and not {@link CallHierarchyOutgoingCall.to `this.to`}.
  """

  typedstruct do
    field(:to, GenLSP.Structures.CallHierarchyItem.t(), enforce: true)
    field(:from_ranges, list(GenLSP.Structures.Range.t()), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"to", :to} => GenLSP.Structures.CallHierarchyItem.schematic(),
      {"fromRanges", :from_ranges} => list(GenLSP.Structures.Range.schematic())
    })
  end
end
