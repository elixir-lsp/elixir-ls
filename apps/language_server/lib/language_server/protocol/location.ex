defmodule ElixirLS.LanguageServer.Protocol.Location do
  @moduledoc """
  Corresponds to the LSP interface of the same name.

  For details see https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#location
  """
  @derive JasonVendored.Encoder
  defstruct [:uri, :range]
end
