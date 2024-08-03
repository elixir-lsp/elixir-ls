defmodule ElixirLS.LanguageServer.CodeFragmentUtils do
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode

  def surround_context_with_fallback(code, {line, column}, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}, options) do
      :none ->
        {NormalizedCode.Fragment.surround_context(code, {line, max(column - 1, 1)}, options),
         column - 1}

      %{context: {:dot, _, _}} ->
        {NormalizedCode.Fragment.surround_context(code, {line, max(column - 1, 1)}, options),
         column - 1}

      context ->
        {context, column}
    end
  end
end
