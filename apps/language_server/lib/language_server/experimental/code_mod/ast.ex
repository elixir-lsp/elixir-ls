defmodule ElixirLS.LanguageServer.Experimental.CodeMod.Ast do
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  @type t :: any()

  def from(%SourceFile{} = source_file) do
    source_file
    |> SourceFile.to_string()
    |> from()
  end

  def from(s) when is_binary(s) do
    parse(s)
  end

  defp parse(s) when is_binary(s) do
    ElixirSense.string_to_quoted(s, 1, 6, token_metadata: true)
  end
end
