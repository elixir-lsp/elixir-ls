# codegen: do not edit
defmodule GenLSP.Structures.DiagnosticOptions do
  @moduledoc """
  Diagnostic options.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * identifier: An optional identifier under which the diagnostics are
    managed by the client.
  * inter_file_dependencies: Whether the language has inter file dependencies meaning that
    editing code in one file can result in a different diagnostic
    set in another file. Inter file dependencies are common for
    most programming languages and typically uncommon for linters.
  * workspace_diagnostics: The server provides support for workspace diagnostics as well.
  * work_done_progress
  """

  typedstruct do
    field(:identifier, String.t())
    field(:inter_file_dependencies, boolean(), enforce: true)
    field(:workspace_diagnostics, boolean(), enforce: true)
    field(:work_done_progress, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"identifier", :identifier}) => str(),
      {"interFileDependencies", :inter_file_dependencies} => bool(),
      {"workspaceDiagnostics", :workspace_diagnostics} => bool(),
      optional({"workDoneProgress", :work_done_progress}) => bool()
    })
  end
end
