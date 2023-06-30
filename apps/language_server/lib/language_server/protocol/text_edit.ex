defmodule ElixirLS.LanguageServer.Protocol.TextEdit do
  @moduledoc """
  Corresponds to the LSP interface of the same name.

  For details see https://microsoft.github.io/language-server-protocol/specification#textEdit
  """
  @derive JasonV.Encoder
  defstruct [:range, :newText]
end
