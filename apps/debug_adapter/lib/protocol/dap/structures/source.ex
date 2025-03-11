# codegen: do not edit
defmodule GenDAP.Structures.Source do
  @moduledoc """
  A `Source` is a descriptor for source code.
  It is returned from the debug adapter as part of a `StackFrame` and it is used by clients when specifying breakpoints.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * name: The short name of the source. Every source returned from the debug adapter has a name.
    When sending a source to the debug adapter this name is optional.
  * path: The path of the source to be shown in the UI.
    It is only used to locate and load the content of the source if no `sourceReference` is specified (or its value is 0).
  * origin: The origin of this source. For example, 'internal module', 'inlined content from source map', etc.
  * sources: A list of sources that are related to this source. These may be the source that generated this source.
  * source_reference: If the value > 0 the contents of the source must be retrieved through the `source` request (even if a path is specified).
    Since a `sourceReference` is only valid for a session, it can not be used to persist a source.
    The value should be less than or equal to 2147483647 (2^31-1).
  * presentation_hint: A hint for how to present the source in the UI.
    A value of `deemphasize` can be used to indicate that the source is not available or that it is skipped on stepping.
  * adapter_data: Additional data that a debug adapter might want to loop through the client.
    The client should leave the data intact and persist it across sessions. The client should not interpret the data.
  * checksums: The checksums associated with this file.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :name, String.t()
    field :path, String.t()
    field :origin, String.t()
    field :sources, list(GenDAP.Structures.Source.t())
    field :source_reference, integer()
    field :presentation_hint, String.t()
    field :adapter_data, list() | boolean() | integer() | nil | number() | map() | String.t()
    field :checksums, list(GenDAP.Structures.Checksum.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"name", :name}) => str(),
      optional({"path", :path}) => str(),
      optional({"origin", :origin}) => str(),
      optional({"sources", :sources}) => list({__MODULE__, :schematic, []}),
      optional({"sourceReference", :source_reference}) => int(),
      optional({"presentationHint", :presentation_hint}) => oneof(["normal", "emphasize", "deemphasize"]),
      optional({"adapterData", :adapter_data}) => oneof([list(), bool(), int(), nil, oneof([int(), float()]), map(), str()]),
      optional({"checksums", :checksums}) => list(GenDAP.Structures.Checksum.schematic()),
    })
  end
end
