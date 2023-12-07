defmodule ElixirLS.LanguageServer.Providers.Implementation do
  @moduledoc """
  textDocument/implementation provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.{Protocol, Parser}

  def implementation(
        uri,
        %Parser.Context{source_file: source_file, metadata: metadata},
        line,
        character,
        project_dir
      ) do
    locations = ElixirSense.implementations(source_file.text, line, character, metadata: metadata)

    results =
      for location <- locations,
          do: Protocol.Location.new(location, uri, source_file.text, project_dir)

    {:ok, results}
  end
end
