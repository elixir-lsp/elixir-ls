defmodule ElixirLS.LanguageServer.Protocol.Location do
  @moduledoc """
  Corresponds to the LSP interface of the same name.

  For details see https://microsoft.github.io/language-server-protocol/specifications/specification-3-15/#location
  """
  @derive JasonV.Encoder
  defstruct [:uri, :range]

  alias ElixirLS.LanguageServer.SourceFile
  require ElixirLS.LanguageServer.Protocol, as: Protocol

  def new(
        %ElixirLS.LanguageServer.Location{file: file, line: line, column: column},
        current_file_uri,
        current_file_text,
        project_dir
      ) do
    uri =
      case file do
        nil -> current_file_uri
        _ -> SourceFile.Path.to_uri(file, project_dir)
      end

    text =
      case file do
        nil -> current_file_text
        file -> File.read!(file)
      end

    {line, column} = SourceFile.elixir_position_to_lsp(text, {line, column})

    %Protocol.Location{
      uri: uri,
      range: Protocol.range(line, column, line + 1, 0)
    }
  end
end
