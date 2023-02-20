defmodule ElixirLS.LanguageServer.Experimental.CodeMod.Location do
  @moduledoc """
  A module that converts ElixirSense location to LSP location.
  """
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Location, as: LSLocation
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.Range, as: LSRange
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions

  def to_lsp(%{line: line, column: column} = elixir_sense_definition, current_source_file) do
    {:ok, current_source_file}
    position = SourceFile.Position.new(line, column - 1)

    with {:ok, source_file} <- fetch_source_file(elixir_sense_definition, current_source_file),
         {:ok, ls_position} <- Conversions.to_lsp(position, source_file) do
      ls_range = %LSRange{start: ls_position, end: ls_position}
      {:ok, LSLocation.new(uri: source_file.uri, range: ls_range)}
    end
  end

  defp fetch_source_file(%{file: nil}, current_source_file) do
    {:ok, current_source_file}
  end

  defp fetch_source_file(%{file: path}, _) do
    SourceFile.Store.open_temporary(path)
  end
end
