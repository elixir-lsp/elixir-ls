defmodule ElixirLS.LanguageServer.Protocol.DocumentSymbol do
  @moduledoc """
  Corresponds to the LSP interface of the same name.

  For details see https://microsoft.github.io/language-server-protocol/specification#textDocument_documentSymbol
  """
  @derive JasonV.Encoder
  defstruct [:name, :detail, :kind, :range, :selectionRange, :children]
end
