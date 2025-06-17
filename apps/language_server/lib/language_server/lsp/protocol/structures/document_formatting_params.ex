# codegen: do not edit
defmodule GenLSP.Structures.DocumentFormattingParams do
  @moduledoc """
  The parameters of a {@link DocumentFormattingRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * text_document: The document to format.
  * options: The format options.
  * work_done_token: An optional token that a server can use to report work done progress.
  """

  typedstruct do
    field(:text_document, GenLSP.Structures.TextDocumentIdentifier.t(), enforce: true)
    field(:options, GenLSP.Structures.FormattingOptions.t(), enforce: true)
    field(:work_done_token, GenLSP.TypeAlias.ProgressToken.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"textDocument", :text_document} => GenLSP.Structures.TextDocumentIdentifier.schematic(),
      {"options", :options} => GenLSP.Structures.FormattingOptions.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
