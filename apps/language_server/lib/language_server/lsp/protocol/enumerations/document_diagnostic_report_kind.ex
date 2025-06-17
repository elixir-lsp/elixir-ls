# codegen: do not edit
defmodule GenLSP.Enumerations.DocumentDiagnosticReportKind do
  @moduledoc """
  The document diagnostic report kinds.

  @since 3.17.0
  """

  @type t :: String.t()

  import SchematicV, warn: false

  @doc """
  A diagnostic report with a full
  set of problems.
  """
  @spec full() :: String.t()
  def full, do: "full"

  @doc """
  A report indicating that the last
  returned report is still accurate.
  """
  @spec unchanged() :: String.t()
  def unchanged, do: "unchanged"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "full",
      "unchanged"
    ])
  end
end
