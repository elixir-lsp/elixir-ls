# codegen: do not edit
defmodule GenLSP.Structures.DocumentOnTypeFormattingParams do
  @moduledoc """
  The parameters of a {@link DocumentOnTypeFormattingRequest}.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * text_document: The document to format.
  * position: The position around which the on type formatting should happen.
    This is not necessarily the exact position where the character denoted
    by the property `ch` got typed.
  * ch: The character that has been typed that triggered the formatting
    on type request. That is not necessarily the last character that
    got inserted into the document since the client could auto insert
    characters as well (e.g. like automatic brace completion).
  * options: The formatting options.
  """

  typedstruct do
    field(:text_document, GenLSP.Structures.TextDocumentIdentifier.t(), enforce: true)
    field(:position, GenLSP.Structures.Position.t(), enforce: true)
    field(:ch, String.t(), enforce: true)
    field(:options, GenLSP.Structures.FormattingOptions.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"textDocument", :text_document} => GenLSP.Structures.TextDocumentIdentifier.schematic(),
      {"position", :position} => GenLSP.Structures.Position.schematic(),
      {"ch", :ch} => str(),
      {"options", :options} => GenLSP.Structures.FormattingOptions.schematic()
    })
  end
end
