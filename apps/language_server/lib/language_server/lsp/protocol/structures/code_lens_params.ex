# codegen: do not edit
defmodule GenLSP.Structures.CodeLensParams do
  @moduledoc """
  The parameters of a {@link CodeLensRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * text_document: The document to request code lens for.
  * work_done_token: An optional token that a server can use to report work done progress.
  * partial_result_token: An optional token that a server can use to report partial results (e.g. streaming) to
    the client.
  """
  
  typedstruct do
    field :text_document, GenLSP.Structures.TextDocumentIdentifier.t(), enforce: true
    field :work_done_token, GenLSP.TypeAlias.ProgressToken.t()
    field :partial_result_token, GenLSP.TypeAlias.ProgressToken.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"textDocument", :text_document} => GenLSP.Structures.TextDocumentIdentifier.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic(),
      optional({"partialResultToken", :partial_result_token}) =>
        GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
