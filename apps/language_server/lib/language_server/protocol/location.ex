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
        %ElixirLS.LanguageServer.Location{
          file: file,
          line: line,
          column: column,
          end_line: end_line,
          end_column: end_column
        },
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
    {end_line, end_column} = SourceFile.elixir_position_to_lsp(text, {end_line, end_column})

    %Protocol.Location{
      uri: uri,
      range: Protocol.range(line, column, end_line, end_column)
    }
  end

  @doc """
  Converts an ElixirLS.LanguageServer.Location to a GenLSP.Structures.Location
  """
  def to_gen_lsp(
        %ElixirLS.LanguageServer.Location{
          file: file,
          line: line,
          column: column,
          end_line: end_line,
          end_column: end_column
        },
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
    {end_line, end_column} = SourceFile.elixir_position_to_lsp(text, {end_line, end_column})

    %GenLSP.Structures.Location{
      uri: uri,
      range: %GenLSP.Structures.Range{
        start: %GenLSP.Structures.Position{line: line, character: column},
        end: %GenLSP.Structures.Position{line: end_line, character: end_column}
      }
    }
  end
end
