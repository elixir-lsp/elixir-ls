# codegen: do not edit
defmodule GenLSP.Structures.GeneralClientCapabilities do
  @moduledoc """
  General client capabilities.

  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * stale_request_support: Client capability that signals how the client
    handles stale requests (e.g. a request
    for which the client will not process the response
    anymore since the information is outdated).

    @since 3.17.0
  * regular_expressions: Client capabilities specific to regular expressions.

    @since 3.16.0
  * markdown: Client capabilities specific to the client's markdown parser.

    @since 3.16.0
  * position_encodings: The position encodings supported by the client. Client and server
    have to agree on the same position encoding to ensure that offsets
    (e.g. character position in a line) are interpreted the same on both
    sides.

    To keep the protocol backwards compatible the following applies: if
    the value 'utf-16' is missing from the array of position encodings
    servers can assume that the client supports UTF-16. UTF-16 is
    therefore a mandatory encoding.

    If omitted it defaults to ['utf-16'].

    Implementation considerations: since the conversion from one encoding
    into another requires the content of the file / line the conversion
    is best done where the file is read which is usually on the server
    side.

    @since 3.17.0
  """

  typedstruct do
    field(:stale_request_support, map())
    field(:regular_expressions, GenLSP.Structures.RegularExpressionsClientCapabilities.t())
    field(:markdown, GenLSP.Structures.MarkdownClientCapabilities.t())
    field(:position_encodings, list(GenLSP.Enumerations.PositionEncodingKind.t()))
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"staleRequestSupport", :stale_request_support}) =>
        map(%{
          {"cancel", :cancel} => bool(),
          {"retryOnContentModified", :retry_on_content_modified} => list(str())
        }),
      optional({"regularExpressions", :regular_expressions}) =>
        GenLSP.Structures.RegularExpressionsClientCapabilities.schematic(),
      optional({"markdown", :markdown}) =>
        GenLSP.Structures.MarkdownClientCapabilities.schematic(),
      optional({"positionEncodings", :position_encodings}) =>
        list(GenLSP.Enumerations.PositionEncodingKind.schematic())
    })
  end
end
