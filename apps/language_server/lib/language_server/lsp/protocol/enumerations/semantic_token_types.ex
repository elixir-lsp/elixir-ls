# codegen: do not edit
defmodule GenLSP.Enumerations.SemanticTokenTypes do
  @moduledoc """
  A set of predefined token types. This set is not fixed
  an clients can specify additional token types via the
  corresponding client capabilities.

  @since 3.16.0
  """

  @type t :: String.t()

  import SchematicV, warn: false

  @spec namespace() :: String.t()
  def namespace, do: "namespace"

  @doc """
  Represents a generic type. Acts as a fallback for types which can't be mapped to
  a specific type like class or enum.
  """
  @spec type() :: String.t()
  def type, do: "type"

  @spec class() :: String.t()
  def class, do: "class"

  @spec enum() :: String.t()
  def enum, do: "enum"

  @spec interface() :: String.t()
  def interface, do: "interface"

  @spec struct() :: String.t()
  def struct, do: "struct"

  @spec type_parameter() :: String.t()
  def type_parameter, do: "typeParameter"

  @spec parameter() :: String.t()
  def parameter, do: "parameter"

  @spec variable() :: String.t()
  def variable, do: "variable"

  @spec property() :: String.t()
  def property, do: "property"

  @spec enum_member() :: String.t()
  def enum_member, do: "enumMember"

  @spec event() :: String.t()
  def event, do: "event"

  @spec function() :: String.t()
  def function, do: "function"

  @spec method() :: String.t()
  def method, do: "method"

  @spec macro() :: String.t()
  def macro, do: "macro"

  @spec keyword() :: String.t()
  def keyword, do: "keyword"

  @spec modifier() :: String.t()
  def modifier, do: "modifier"

  @spec comment() :: String.t()
  def comment, do: "comment"

  @spec string() :: String.t()
  def string, do: "string"

  @spec number() :: String.t()
  def number, do: "number"

  @spec regexp() :: String.t()
  def regexp, do: "regexp"

  @spec operator() :: String.t()
  def operator, do: "operator"

  @doc """
  @since 3.17.0
  """
  @spec decorator() :: String.t()
  def decorator, do: "decorator"

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      "namespace",
      "type",
      "class",
      "enum",
      "interface",
      "struct",
      "typeParameter",
      "parameter",
      "variable",
      "property",
      "enumMember",
      "event",
      "function",
      "method",
      "macro",
      "keyword",
      "modifier",
      "comment",
      "string",
      "number",
      "regexp",
      "operator",
      "decorator",
      str()
    ])
  end
end
