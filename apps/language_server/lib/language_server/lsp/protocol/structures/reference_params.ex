# codegen: do not edit
defmodule GenLSP.Structures.ReferenceParams do
  @moduledoc """
  Parameters for a {@link ReferencesRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * context
  * work_done_token: An optional token that a server can use to report work done progress.
  * partial_result_token: An optional token that a server can use to report partial results (e.g. streaming) to
    the client.
  * text_document: The text document.
  * position: The position inside the text document.
  """
  
  typedstruct do
    field :context, GenLSP.Structures.ReferenceContext.t(), enforce: true
    field :work_done_token, GenLSP.TypeAlias.ProgressToken.t()
    field :partial_result_token, GenLSP.TypeAlias.ProgressToken.t()
    field :text_document, GenLSP.Structures.TextDocumentIdentifier.t(), enforce: true
    field :position, GenLSP.Structures.Position.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"context", :context} => GenLSP.Structures.ReferenceContext.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic(),
      optional({"partialResultToken", :partial_result_token}) =>
        GenLSP.TypeAlias.ProgressToken.schematic(),
      {"textDocument", :text_document} => GenLSP.Structures.TextDocumentIdentifier.schematic(),
      {"position", :position} => GenLSP.Structures.Position.schematic()
    })
  end
end
