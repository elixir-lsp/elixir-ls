# codegen: do not edit
defmodule GenLSP.Structures.ShowDocumentParams do
  @moduledoc """
  Params to show a document.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * uri: The document uri to show.
  * external: Indicates to show the resource in an external program.
    To show for example `https://code.visualstudio.com/`
    in the default WEB browser set `external` to `true`.
  * take_focus: An optional property to indicate whether the editor
    showing the document should take focus or not.
    Clients might ignore this property if an external
    program is started.
  * selection: An optional selection range if the document is a text
    document. Clients might ignore the property if an
    external program is started or the file is not a text
    file.
  """
  
  typedstruct do
    field :uri, GenLSP.BaseTypes.uri(), enforce: true
    field :external, boolean()
    field :take_focus, boolean()
    field :selection, GenLSP.Structures.Range.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"uri", :uri} => str(),
      optional({"external", :external}) => bool(),
      optional({"takeFocus", :take_focus}) => bool(),
      optional({"selection", :selection}) => GenLSP.Structures.Range.schematic()
    })
  end
end
