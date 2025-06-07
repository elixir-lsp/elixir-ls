# codegen: do not edit
defmodule GenLSP.Structures.InlineValueParams do
  @moduledoc """
  A parameter literal used in inline value requests.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * text_document: The text document.
  * range: The document range for which inline values should be computed.
  * context: Additional information about the context in which inline values were
    requested.
  * work_done_token: An optional token that a server can use to report work done progress.
  """
  
  typedstruct do
    field :text_document, GenLSP.Structures.TextDocumentIdentifier.t(), enforce: true
    field :range, GenLSP.Structures.Range.t(), enforce: true
    field :context, GenLSP.Structures.InlineValueContext.t(), enforce: true
    field :work_done_token, GenLSP.TypeAlias.ProgressToken.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"textDocument", :text_document} => GenLSP.Structures.TextDocumentIdentifier.schematic(),
      {"range", :range} => GenLSP.Structures.Range.schematic(),
      {"context", :context} => GenLSP.Structures.InlineValueContext.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
