defmodule ElixirLS.LanguageServer.Protocol.SymbolInformation do
  @moduledoc """
  Corresponds to the LSP interface of the same name.

  For details see https://microsoft.github.io/language-server-protocol/specification#textDocument_documentSymbol
  """
  @derive JasonVendored.Encoder
  defstruct [:name, :kind, :location, :containerName]
end
