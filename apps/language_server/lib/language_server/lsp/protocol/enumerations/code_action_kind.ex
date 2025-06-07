# codegen: do not edit
defmodule GenLSP.Enumerations.CodeActionKind do
  @moduledoc """
  A set of predefined code action kinds
  """

  @type t :: String.t()

  import Schematic, warn: false

  @doc """
  Empty kind.
  """
  @spec empty() :: String.t()
  def empty, do: ""

  @doc """
  Base kind for quickfix actions: 'quickfix'
  """
  @spec quick_fix() :: String.t()
  def quick_fix, do: "quickfix"

  @doc """
  Base kind for refactoring actions: 'refactor'
  """
  @spec refactor() :: String.t()
  def refactor, do: "refactor"

  @doc """
  Base kind for refactoring extraction actions: 'refactor.extract'

  Example extract actions:

  - Extract method
  - Extract function
  - Extract variable
  - Extract interface from class
  - ...
  """
  @spec refactor_extract() :: String.t()
  def refactor_extract, do: "refactor.extract"

  @doc """
  Base kind for refactoring inline actions: 'refactor.inline'

  Example inline actions:

  - Inline function
  - Inline variable
  - Inline constant
  - ...
  """
  @spec refactor_inline() :: String.t()
  def refactor_inline, do: "refactor.inline"

  @doc """
  Base kind for refactoring rewrite actions: 'refactor.rewrite'

  Example rewrite actions:

  - Convert JavaScript function to class
  - Add or remove parameter
  - Encapsulate field
  - Make method static
  - Move method to base class
  - ...
  """
  @spec refactor_rewrite() :: String.t()
  def refactor_rewrite, do: "refactor.rewrite"

  @doc """
  Base kind for source actions: `source`

  Source code actions apply to the entire file.
  """
  @spec source() :: String.t()
  def source, do: "source"

  @doc """
  Base kind for an organize imports source action: `source.organizeImports`
  """
  @spec source_organize_imports() :: String.t()
  def source_organize_imports, do: "source.organizeImports"

  @doc """
  Base kind for auto-fix source actions: `source.fixAll`.

  Fix all actions automatically fix errors that have a clear fix that do not require user input.
  They should not suppress errors or perform unsafe fixes such as generating new types or classes.

  @since 3.15.0
  """
  @spec source_fix_all() :: String.t()
  def source_fix_all, do: "source.fixAll"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "",
      "quickfix",
      "refactor",
      "refactor.extract",
      "refactor.inline",
      "refactor.rewrite",
      "source",
      "source.organizeImports",
      "source.fixAll",
      str()
    ])
  end
end
