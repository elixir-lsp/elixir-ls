defmodule ElixirLS.LanguageServer.Providers.CodeMod.Ast do
  alias ElixirLS.LanguageServer.SourceFile

  @type source :: SourceFile.t() | String.t()
  @type t ::
          atom()
          | binary()
          | [any()]
          | number()
          | {any(), any()}
          | {atom() | {any(), [any()], atom() | [any()]}, Keyword.t(), atom() | [any()]}

  @spec from(source() | String.t()) :: {:ok, t()} | :error
  def from(%SourceFile{text: text}) do
    from(text)
  end

  def from(text) when is_binary(text) do
    case ElixirSense.string_to_quoted(text, {1, 1}) do
      {:ok, ast} -> {:ok, ast}
      _ -> :error
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(ast) do
    Macro.to_string(ast)
  end
end
