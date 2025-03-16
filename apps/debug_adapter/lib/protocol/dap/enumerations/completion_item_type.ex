# codegen: do not edit
defmodule GenDAP.Enumerations.CompletionItemType do
  @moduledoc """
  Some predefined types for the CompletionItem. Please note that not all clients have specific icons for all of them.
  """

  @typedoc "A type defining DAP enumeration CompletionItemType"
  @type t :: String.t()

  import Schematic, warn: false

  @spec method() :: String.t()
  def method, do: "method"

  @spec function() :: String.t()
  def function, do: "function"

  @spec constructor() :: String.t()
  def constructor, do: "constructor"

  @spec field() :: String.t()
  def field, do: "field"

  @spec variable() :: String.t()
  def variable, do: "variable"

  @spec class() :: String.t()
  def class, do: "class"

  @spec interface() :: String.t()
  def interface, do: "interface"

  @spec module() :: String.t()
  def module, do: "module"

  @spec property() :: String.t()
  def property, do: "property"

  @spec unit() :: String.t()
  def unit, do: "unit"

  @spec value() :: String.t()
  def value, do: "value"

  @spec enum() :: String.t()
  def enum, do: "enum"

  @spec keyword() :: String.t()
  def keyword, do: "keyword"

  @spec snippet() :: String.t()
  def snippet, do: "snippet"

  @spec text() :: String.t()
  def text, do: "text"

  @spec color() :: String.t()
  def color, do: "color"

  @spec file() :: String.t()
  def file, do: "file"

  @spec reference() :: String.t()
  def reference, do: "reference"

  @spec customcolor() :: String.t()
  def customcolor, do: "customcolor"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "method",
      "function",
      "constructor",
      "field",
      "variable",
      "class",
      "interface",
      "module",
      "property",
      "unit",
      "value",
      "enum",
      "keyword",
      "snippet",
      "text",
      "color",
      "file",
      "reference",
      "customcolor"
    ])
  end
end
