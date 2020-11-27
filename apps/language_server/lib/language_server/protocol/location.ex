defmodule ElixirLS.LanguageServer.Protocol.Location do
  @moduledoc """
  Corresponds to the LSP interface of the same name.

  For details see https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#location
  """
  @derive JasonVendored.Encoder
  defstruct [:uri, :range]

  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Protocol

  def new(%ElixirSense.Location{file: file, line: line, column: column}, uri) do
    uri =
      case file do
        nil -> uri
        _ -> SourceFile.path_to_uri(file)
      end

    %Protocol.Location{
      uri: uri,
      range: %{
        "start" => %{"line" => line - 1, "character" => column - 1},
        "end" => %{"line" => line - 1, "character" => column - 1}
      }
    }
  end
end
