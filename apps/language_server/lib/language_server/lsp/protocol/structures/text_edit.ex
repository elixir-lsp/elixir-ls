# codegen: do not edit
defmodule GenLSP.Structures.TextEdit do
  @moduledoc """
  A text edit applicable to a text document.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * range: The range of the text document to be manipulated. To insert
    text into a document create a range where start === end.
  * new_text: The string to be inserted. For delete operations use an
    empty string.
  """
  
  typedstruct do
    field :range, GenLSP.Structures.Range.t(), enforce: true
    field :new_text, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"range", :range} => GenLSP.Structures.Range.schematic(),
      {"newText", :new_text} => str()
    })
  end
end
