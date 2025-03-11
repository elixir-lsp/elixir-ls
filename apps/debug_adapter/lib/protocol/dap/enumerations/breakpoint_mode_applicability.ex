# codegen: do not edit
defmodule GenDAP.Enumerations.BreakpointModeApplicability do
  @moduledoc """
  Describes one or more type of breakpoint a `BreakpointMode` applies to. This is a non-exhaustive enumeration and may expand as future breakpoint types are added.
  """

  @type t :: String.t()

  import Schematic, warn: false

  @doc """
  In `SourceBreakpoint`s
  """
  @spec source() :: String.t()
  def source, do: "source"
  @doc """
  In exception breakpoints applied in the `ExceptionFilterOptions`
  """
  @spec exception() :: String.t()
  def exception, do: "exception"
  @doc """
  In data breakpoints requested in the `DataBreakpointInfo` request
  """
  @spec data() :: String.t()
  def data, do: "data"
  @doc """
  In `InstructionBreakpoint`s
  """
  @spec instruction() :: String.t()
  def instruction, do: "instruction"
  
  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "source",
      "exception",
      "data",
      "instruction",
    ])
  end
end
