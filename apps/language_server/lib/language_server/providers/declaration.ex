defmodule ElixirLS.LanguageServer.Providers.Declaration do
  @moduledoc """
  textDocument/declaration provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.{Protocol, Parser}
  alias ElixirLS.LanguageServer.Providers.Declaration.Locator

  def declaration(
        uri,
        %Parser.Context{source_file: source_file, metadata: metadata},
        line,
        character,
        project_dir
      ) do
    result =
      case Locator.declaration(source_file.text, line, character, metadata: metadata) do
        nil ->
          nil

        %ElixirLS.LanguageServer.Location{} = location ->
          Protocol.Location.new(location, uri, source_file.text, project_dir)
      end

    {:ok, result}
  end
end
