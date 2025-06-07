# codegen: do not edit
defmodule GenLSP.Enumerations.MarkupKind do
  @moduledoc """
  Describes the content type that a client supports in various
  result literals like `Hover`, `ParameterInfo` or `CompletionItem`.

  Please note that `MarkupKinds` must not start with a `$`. This kinds
  are reserved for internal usage.
  """

  @type t :: String.t()

  import Schematic, warn: false

  @doc """
  Plain text is supported as a content format
  """
  @spec plain_text() :: String.t()
  def plain_text, do: "plaintext"

  @doc """
  Markdown is supported as a content format
  """
  @spec markdown() :: String.t()
  def markdown, do: "markdown"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "plaintext",
      "markdown"
    ])
  end
end
