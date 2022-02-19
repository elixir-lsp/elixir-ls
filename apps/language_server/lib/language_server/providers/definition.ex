defmodule ElixirLS.LanguageServer.Providers.Definition do
  @moduledoc """
  Go-to-definition provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.{Protocol, SourceFile}

  def definition(uri, text, line, character) do
    {line, character} = SourceFile.lsp_position_to_elixir(text, {line, character})

    result =
      case ElixirSense.definition(text, line, character) do
        nil ->
          nil

        %ElixirSense.Location{} = location ->
          Protocol.Location.new(location, uri, text)
      end

    {:ok, result}
  end
end
