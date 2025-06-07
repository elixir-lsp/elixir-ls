# codegen: do not edit
defmodule GenLSP.Enumerations.SemanticTokenModifiers do
  @moduledoc """
  A set of predefined token modifiers. This set is not fixed
  an clients can specify additional token types via the
  corresponding client capabilities.

  @since 3.16.0
  """

  @type t :: String.t()

  import Schematic, warn: false

  @spec declaration() :: String.t()
  def declaration, do: "declaration"

  @spec definition() :: String.t()
  def definition, do: "definition"

  @spec readonly() :: String.t()
  def readonly, do: "readonly"

  @spec static() :: String.t()
  def static, do: "static"

  @spec deprecated() :: String.t()
  def deprecated, do: "deprecated"

  @spec abstract() :: String.t()
  def abstract, do: "abstract"

  @spec async() :: String.t()
  def async, do: "async"

  @spec modification() :: String.t()
  def modification, do: "modification"

  @spec documentation() :: String.t()
  def documentation, do: "documentation"

  @spec default_library() :: String.t()
  def default_library, do: "defaultLibrary"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "declaration",
      "definition",
      "readonly",
      "static",
      "deprecated",
      "abstract",
      "async",
      "modification",
      "documentation",
      "defaultLibrary",
      str()
    ])
  end
end
