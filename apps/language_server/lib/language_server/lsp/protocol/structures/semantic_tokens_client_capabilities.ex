# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokensClientCapabilities do
  @moduledoc """
  @since 3.16.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether implementation supports dynamic registration. If this is set to `true`
    the client supports the new `(TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    return value for the corresponding server capability as well.
  * requests: Which requests the client supports and might send to the server
    depending on the server's capability. Please note that clients might not
    show semantic tokens or degrade some of the user experience if a range
    or full request is advertised by the client but not provided by the
    server. If for example the client capability `requests.full` and
    `request.range` are both set to true but the server only provides a
    range provider the client might not render a minimap correctly or might
    even decide to not show any semantic tokens at all.
  * token_types: The token types that the client supports.
  * token_modifiers: The token modifiers that the client supports.
  * formats: The token formats the clients supports.
  * overlapping_token_support: Whether the client supports tokens that can overlap each other.
  * multiline_token_support: Whether the client supports tokens that can span multiple lines.
  * server_cancel_support: Whether the client allows the server to actively cancel a
    semantic token request, e.g. supports returning
    LSPErrorCodes.ServerCancelled. If a server does the client
    needs to retrigger the request.

    @since 3.17.0
  * augments_syntax_tokens: Whether the client uses semantic tokens to augment existing
    syntax tokens. If set to `true` client side created syntax
    tokens and semantic tokens are both used for colorization. If
    set to `false` the client only uses the returned semantic tokens
    for colorization.

    If the value is `undefined` then the client behavior is not
    specified.

    @since 3.17.0
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:requests, map(), enforce: true)
    field(:token_types, list(String.t()), enforce: true)
    field(:token_modifiers, list(String.t()), enforce: true)
    field(:formats, list(GenLSP.Enumerations.TokenFormat.t()), enforce: true)
    field(:overlapping_token_support, boolean())
    field(:multiline_token_support, boolean())
    field(:server_cancel_support, boolean())
    field(:augments_syntax_tokens, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      {"requests", :requests} =>
        map(%{
          optional({"range", :range}) => oneof([bool(), map(%{})]),
          optional({"full", :full}) =>
            oneof([
              bool(),
              map(%{
                optional({"delta", :delta}) => bool()
              })
            ])
        }),
      {"tokenTypes", :token_types} => list(str()),
      {"tokenModifiers", :token_modifiers} => list(str()),
      {"formats", :formats} => list(GenLSP.Enumerations.TokenFormat.schematic()),
      optional({"overlappingTokenSupport", :overlapping_token_support}) => bool(),
      optional({"multilineTokenSupport", :multiline_token_support}) => bool(),
      optional({"serverCancelSupport", :server_cancel_support}) => bool(),
      optional({"augmentsSyntaxTokens", :augments_syntax_tokens}) => bool()
    })
  end
end
