# codegen: do not edit
defmodule GenLSP.Structures.DiagnosticRegistrationOptions do
  @moduledoc """
  Diagnostic registration options.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * id: The id used to register the request. The id can be used to deregister
    the request again. See also Registration#id.
  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  * identifier: An optional identifier under which the diagnostics are
    managed by the client.
  * inter_file_dependencies: Whether the language has inter file dependencies meaning that
    editing code in one file can result in a different diagnostic
    set in another file. Inter file dependencies are common for
    most programming languages and typically uncommon for linters.
  * workspace_diagnostics: The server provides support for workspace diagnostics as well.
  """

  typedstruct do
    field(:id, String.t())
    field(:document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true)
    field(:identifier, String.t())
    field(:inter_file_dependencies, boolean(), enforce: true)
    field(:workspace_diagnostics, boolean(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"id", :id}) => str(),
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil]),
      optional({"identifier", :identifier}) => str(),
      {"interFileDependencies", :inter_file_dependencies} => bool(),
      {"workspaceDiagnostics", :workspace_diagnostics} => bool()
    })
  end
end
