# codegen: do not edit
defmodule GenLSP.Structures.RenameParams do
  @moduledoc """
  The parameters of a {@link RenameRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * text_document: The document to rename.
  * position: The position at which this request was sent.
  * new_name: The new name of the symbol. If the given name is not valid the
    request must return a {@link ResponseError} with an
    appropriate message set.
  * work_done_token: An optional token that a server can use to report work done progress.
  """

  typedstruct do
    field(:text_document, GenLSP.Structures.TextDocumentIdentifier.t(), enforce: true)
    field(:position, GenLSP.Structures.Position.t(), enforce: true)
    field(:new_name, String.t(), enforce: true)
    field(:work_done_token, GenLSP.TypeAlias.ProgressToken.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"textDocument", :text_document} => GenLSP.Structures.TextDocumentIdentifier.schematic(),
      {"position", :position} => GenLSP.Structures.Position.schematic(),
      {"newName", :new_name} => str(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
