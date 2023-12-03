defmodule ElixirLS.LanguageServer.Providers.Definition do
  @moduledoc """
  textDocument/definition provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.{Protocol, SourceFile, Parser}

  def definition(uri, %Parser.Context{source_file: source_file, metadata: metadata}, line, character, project_dir) do
    {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})

    result =
      case ElixirSense.definition(source_file.text, line, character, if(metadata, do: [metadata: metadata], else: [])) do
        nil ->
          nil

        %ElixirSense.Location{} = location ->
          Protocol.Location.new(location, uri, source_file.text, project_dir)
      end

    {:ok, result}
  end
end
