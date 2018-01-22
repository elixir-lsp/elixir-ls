defmodule ElixirLS.LanguageServer.Providers.Definition do
  @moduledoc """
  Go-to-definition provider utilizing Elixir Sense
  """

  alias ElixirLS.LanguageServer.SourceFile

  def definition(text, line, character) do
    case ElixirSense.definition(text, line + 1, character + 1) do
      {"non_existing", nil} ->
        {:ok, []}

      {file, line} ->
        line = line || 0
        uri = SourceFile.path_to_uri(file)

        {:ok,
         %{
           "uri" => uri,
           "range" => %{
             "start" => %{"line" => line - 1, "character" => 0},
             "end" => %{"line" => line - 1, "character" => 0}
           }
         }}
    end
  end
end
