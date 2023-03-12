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

  def from(source_file, opts \\ [])

  @spec from(source, keyword()) :: t
  def from(%SourceFile{} = source_file, opts) do
    source_file
    |> SourceFile.to_string()
    |> from(opts)
  end

  def from(s, opts) when is_binary(s) do
    if opts[:include_comments] do
      Sourceror.parse_string(s)
    else
      ElixirSense.string_to_quoted(s, 1, 6, token_metadata: true)
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(ast) do
    Sourceror.to_string(ast)
  end
end
