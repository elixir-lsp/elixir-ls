defmodule ElixirLS.LanguageServer.Providers.Definition do
  @moduledoc """
  textDocument/definition provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.{Protocol, Parser}
  alias ElixirLS.LanguageServer.Providers.Definition.Locator

  def definition(
        uri,
        %Parser.Context{source_file: source_file, metadata: metadata},
        line,
        character,
        project_dir
      ) do
    result =
      case Locator.definition(source_file.text, line, character, metadata: metadata) do
        nil ->
          nil

        %ElixirLS.LanguageServer.Location{} = location ->
          Protocol.Location.new(location, uri, source_file.text, project_dir)
      end

    {:ok, result}
  end
end
