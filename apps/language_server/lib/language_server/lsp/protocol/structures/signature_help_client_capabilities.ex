# codegen: do not edit
defmodule GenLSP.Structures.SignatureHelpClientCapabilities do
  @moduledoc """
  Client Capabilities for a {@link SignatureHelpRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether signature help supports dynamic registration.
  * signature_information: The client supports the following `SignatureInformation`
    specific properties.
  * context_support: The client supports to send additional context information for a
    `textDocument/signatureHelp` request. A client that opts into
    contextSupport will also support the `retriggerCharacters` on
    `SignatureHelpOptions`.

    @since 3.15.0
  """
  
  typedstruct do
    field :dynamic_registration, boolean()
    field :signature_information, map()
    field :context_support, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"signatureInformation", :signature_information}) =>
        map(%{
          optional({"documentationFormat", :documentation_format}) =>
            list(GenLSP.Enumerations.MarkupKind.schematic()),
          optional({"parameterInformation", :parameter_information}) =>
            map(%{
              optional({"labelOffsetSupport", :label_offset_support}) => bool()
            }),
          optional({"activeParameterSupport", :active_parameter_support}) => bool()
        }),
      optional({"contextSupport", :context_support}) => bool()
    })
  end
end
