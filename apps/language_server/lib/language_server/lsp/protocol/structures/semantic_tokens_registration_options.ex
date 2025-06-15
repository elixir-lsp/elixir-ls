# codegen: do not edit
defmodule GenLSP.Structures.SemanticTokensRegistrationOptions do
  @moduledoc """
  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * id: The id used to register the request. The id can be used to deregister
    the request again. See also Registration#id.
  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  * legend: The legend used by the server
  * range: Server supports providing semantic tokens for a specific range
    of a document.
  * full: Server supports providing semantic tokens for a full document.
  """

  typedstruct do
    field(:id, String.t())
    field(:document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true)
    field(:legend, GenLSP.Structures.SemanticTokensLegend.t(), enforce: true)
    field(:range, boolean() | map())
    field(:full, boolean() | map())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"id", :id}) => str(),
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil]),
      {"legend", :legend} => GenLSP.Structures.SemanticTokensLegend.schematic(),
      optional({"range", :range}) => oneof([bool(), map(%{})]),
      optional({"full", :full}) =>
        oneof([
          bool(),
          map(%{
            optional({"delta", :delta}) => bool()
          })
        ])
    })
  end
end
