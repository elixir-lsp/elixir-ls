# codegen: do not edit
defmodule GenLSP.Enumerations.DiagnosticTag do
  @moduledoc """
  The diagnostic tags.

  @since 3.15.0
  """

  @type t :: 1 | 2

  import Schematic, warn: false

  @doc """
  Unused or unnecessary code.

  Clients are allowed to render diagnostics with this tag faded out instead of having
  an error squiggle.
  """
  @spec unnecessary() :: 1
  def unnecessary, do: 1

  @doc """
  Deprecated or obsolete code.

  Clients are allowed to rendered diagnostics with this tag strike through.
  """
  @spec deprecated() :: 2
  def deprecated, do: 2

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      1,
      2
    ])
  end
end
