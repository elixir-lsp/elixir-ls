defmodule ElixirLS.LanguageServer.Providers.Implementation do
  @moduledoc """
  Go-to-implementation provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.{Protocol, SourceFile}

  def implementation(uri, text, line, character) do
    {line, character} = SourceFile.lsp_position_to_elixir(text, {line, character})
    locations = ElixirSense.implementations(text, line, character)
    results = for location <- locations, do: Protocol.Location.new(location, uri, text)

    {:ok, results}
  end
end
