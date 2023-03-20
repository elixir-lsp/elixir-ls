defmodule ElixirLS.LanguageServer.Experimental.CodeMod.RefactorExtractFunction do
  alias ElixirLS.LanguageServer.Experimental.CodeMod.Diff
  alias ElixirLS.LanguageServer.Experimental.CodeMod.ExtractFunction

  alias Sourceror.Zipper

  require Logger

  def text_edits(original_text, tree, start_line, end_line, new_function_name) do
    result =
      tree
      |> Zipper.zip()
      |> ExtractFunction.extract_function(start_line + 1, end_line + 1, new_function_name)
      |> Sourceror.to_string()

    {:ok, Diff.diff(original_text, result)}
  end
end
