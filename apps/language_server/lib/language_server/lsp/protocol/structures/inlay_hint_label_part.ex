# codegen: do not edit
defmodule GenLSP.Structures.InlayHintLabelPart do
  @moduledoc """
  An inlay hint label part allows for interactive and composite labels
  of inlay hints.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * value: The value of this label part.
  * tooltip: The tooltip text when you hover over this label part. Depending on
    the client capability `inlayHint.resolveSupport` clients might resolve
    this property late using the resolve request.
  * location: An optional source code location that represents this
    label part.

    The editor will use this location for the hover and for code navigation
    features: This part will become a clickable link that resolves to the
    definition of the symbol at the given location (not necessarily the
    location itself), it shows the hover that shows at the given location,
    and it shows a context menu with further code navigation commands.

    Depending on the client capability `inlayHint.resolveSupport` clients
    might resolve this property late using the resolve request.
  * command: An optional command for this label part.

    Depending on the client capability `inlayHint.resolveSupport` clients
    might resolve this property late using the resolve request.
  """

  typedstruct do
    field(:value, String.t(), enforce: true)
    field(:tooltip, String.t() | GenLSP.Structures.MarkupContent.t())
    field(:location, GenLSP.Structures.Location.t())
    field(:command, GenLSP.Structures.Command.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"value", :value} => str(),
      optional({"tooltip", :tooltip}) =>
        oneof([str(), GenLSP.Structures.MarkupContent.schematic()]),
      optional({"location", :location}) => GenLSP.Structures.Location.schematic(),
      optional({"command", :command}) => GenLSP.Structures.Command.schematic()
    })
  end
end
