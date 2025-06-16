# codegen: do not edit
defmodule GenDAP.Enumerations.SteppingGranularity do
  @moduledoc """
  The granularity of one 'step' in the stepping requests `next`, `stepIn`, `stepOut`, and `stepBack`.
  """

  @typedoc "A type defining DAP enumeration SteppingGranularity"
  @type t :: String.t()

  import SchematicV, warn: false

  @doc """
  The step should allow the program to run until the current statement has finished executing.
  The meaning of a statement is determined by the adapter and it may be considered equivalent to a line.
  For example 'for(int i = 0; i < 10; i++)' could be considered to have 3 statements 'int i = 0', 'i < 10', and 'i++'.
  """
  @spec statement() :: String.t()
  def statement, do: "statement"

  @doc """
  The step should allow the program to run until the current source line has executed.
  """
  @spec line() :: String.t()
  def line, do: "line"

  @doc """
  The step should allow one instruction to execute (e.g. one x86 instruction).
  """
  @spec instruction() :: String.t()
  def instruction, do: "instruction"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "statement",
      "line",
      "instruction"
    ])
  end
end
