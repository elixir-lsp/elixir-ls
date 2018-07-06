defmodule ElixirLS.LanguageServer.Providers.Definition do
  @moduledoc """
  Go-to-definition provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Providers.Definition.Location

  def definition(uri, text, line, character) do
    case ElixirSense.definition(text, line + 1, character + 1) do
      %Location{found: false} ->
        {:ok, []}

      %Location{file: file, line: line, column: column} ->
        line = line || 0
        column = column || 0
        uri =
          case file do
            nil -> uri
            _ -> SourceFile.path_to_uri(file)
          end

        {:ok,
         %{
           "uri" => uri,
           "range" => %{
             "start" => %{"line" => line - 1, "character" => column - 1},
             "end" => %{"line" => line - 1, "character" => column - 1}
           }
         }}
    end
  end
end
