defmodule ElixirLS.LanguageServer.Experimental.CodeMod.Ast do
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  @type source :: SourceFile.t() | String.t()
  @type t ::
          atom()
          | binary()
          | [any()]
          | number()
          | {any(), any()}
          | {atom() | {any(), [any()], atom() | [any()]}, Keyword.t(), atom() | [any()]}

  @spec from(source) :: t
  def from(%SourceFile{} = source_file) do
    source_file
    |> SourceFile.to_string()
    |> from()
  end

  def from(s) when is_binary(s) do
    ElixirSense.string_to_quoted(s, 1, 6, token_metadata: true)
  end

  @spec to_string(t()) :: String.t()
  def to_string(ast) do
    Macro.to_string(ast)
  end
end
