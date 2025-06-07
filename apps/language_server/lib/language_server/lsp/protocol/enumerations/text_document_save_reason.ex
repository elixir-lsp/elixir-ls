# codegen: do not edit
defmodule GenLSP.Enumerations.TextDocumentSaveReason do
  @moduledoc """
  Represents reasons why a text document is saved.
  """

  @type t :: 1 | 2 | 3

  import Schematic, warn: false

  @doc """
  Manually triggered, e.g. by the user pressing save, by starting debugging,
  or by an API call.
  """
  @spec manual() :: 1
  def manual, do: 1

  @doc """
  Automatic after a delay.
  """
  @spec after_delay() :: 2
  def after_delay, do: 2

  @doc """
  When the editor lost focus.
  """
  @spec focus_out() :: 3
  def focus_out, do: 3

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      1,
      2,
      3
    ])
  end
end
