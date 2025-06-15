# codegen: do not edit
defmodule GenLSP.Structures.SignatureHelpParams do
  @moduledoc """
  Parameters for a {@link SignatureHelpRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * context: The signature help context. This is only available if the client specifies
    to send this using the client capability `textDocument.signatureHelp.contextSupport === true`

    @since 3.15.0
  * work_done_token: An optional token that a server can use to report work done progress.
  * text_document: The text document.
  * position: The position inside the text document.
  """

  typedstruct do
    field(:context, GenLSP.Structures.SignatureHelpContext.t())
    field(:work_done_token, GenLSP.TypeAlias.ProgressToken.t())
    field(:text_document, GenLSP.Structures.TextDocumentIdentifier.t(), enforce: true)
    field(:position, GenLSP.Structures.Position.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"context", :context}) => GenLSP.Structures.SignatureHelpContext.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic(),
      {"textDocument", :text_document} => GenLSP.Structures.TextDocumentIdentifier.schematic(),
      {"position", :position} => GenLSP.Structures.Position.schematic()
    })
  end
end
