defmodule ElixirLS.LanguageServer.Providers.CodeMod.Ast do
  alias ElixirLS.LanguageServer.SourceFile

  @spec from(SourceFile.t() | String.t()) :: {:ok, Macro.t(), [map()]} | :error
  def from(%SourceFile{text: text}) do
    from(text)
  end

  def from(text) when is_binary(text) do
    text = String.trim(text)

    to_quoted_opts =
      [
        literal_encoder: &{:ok, {:__block__, &2, [&1]}},
        token_metadata: true,
        unescape: false
      ]

    case Code.string_to_quoted_with_comments(text, to_quoted_opts) do
      {:ok, ast, comments} -> {:ok, ast, comments}
      _ -> :error
    end
  end

  @spec to_string(Macro.t(), [map()]) :: String.t()
  def to_string(ast, comments) do
    to_algebra_opts = [comments: comments, escape: false]

    ast
    |> Code.quoted_to_algebra(to_algebra_opts)
    |> Inspect.Algebra.format(:infinity)
    |> IO.iodata_to_binary()
  end
end
