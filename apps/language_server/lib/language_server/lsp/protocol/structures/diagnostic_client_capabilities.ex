# codegen: do not edit
defmodule GenLSP.Structures.DiagnosticClientCapabilities do
  @moduledoc """
  Client capabilities specific to diagnostic pull requests.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether implementation supports dynamic registration. If this is set to `true`
    the client supports the new `(TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    return value for the corresponding server capability as well.
  * related_document_support: Whether the clients supports related documents for document diagnostic pulls.
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:related_document_support, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"relatedDocumentSupport", :related_document_support}) => bool()
    })
  end
end
