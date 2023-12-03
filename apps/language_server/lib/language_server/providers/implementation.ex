defmodule ElixirLS.LanguageServer.Providers.Implementation do
  @moduledoc """
  textDocument/implementation provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.{Protocol, SourceFile, Parser}

  def implementation(uri, %Parser.Context{source_file: source_file, metadata: metadata}, line, character, project_dir) do
    {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})
    locations = ElixirSense.implementations(source_file.text, line, character, if(metadata, do: [metadata: metadata], else: []))

    results =
      for location <- locations, do: Protocol.Location.new(location, uri, source_file.text, project_dir)

    {:ok, results}
  end
end
