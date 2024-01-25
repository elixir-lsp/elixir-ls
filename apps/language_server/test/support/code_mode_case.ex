defmodule ElixirLS.LanguageServer.Test.CodeMod.Case do
  alias ElixirLS.LanguageServer.SourceFile

  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__), only: [sigil_q: 2]

      def apply_code_mod(_original_text, _options) do
        {:error, "You must implement apply_code_mod/2"}
      end

      def filter_edited_texts(edited_texts, _options) do
        {:ok, edited_texts}
      end

      defoverridable apply_code_mod: 2, filter_edited_texts: 2

      def modify(original, options \\ []) do
        with {:ok, changes} <- apply_code_mod(original, options) do
          original
          |> unquote(__MODULE__).apply_changes(changes, options)
          |> filter_edited_texts(options)
        end
      end
    end
  end

  def apply_changes(original_text, changes, opts) do
    Enum.map(changes, fn text_edits ->
      %SourceFile{text: edited_text} =
        %SourceFile{text: original_text, version: 0}
        |> SourceFile.apply_content_changes(text_edits)

      if Keyword.get(opts, :trim, true) do
        String.trim(edited_text)
      else
        edited_text
      end
    end)
  end

  def sigil_q(text, opts \\ []) do
    {first, rest} =
      case String.split(text, "\n") do
        ["", first | rest] -> {first, rest}
        [first | rest] -> {first, rest}
      end

    base_indent = indent(first)
    indent_length = String.length(base_indent)

    [first | rest]
    |> Enum.map_join("\n", &strip_leading_indent(&1, indent_length))
    |> maybe_trim(opts)
  end

  @indent_re ~r/^\s*/
  defp indent(first_line) do
    case Regex.scan(@indent_re, first_line) do
      [[indent]] -> indent
      _ -> ""
    end
  end

  defp strip_leading_indent(s, 0) do
    s
  end

  defp strip_leading_indent(<<" ", rest::binary>>, count) when count > 0 do
    strip_leading_indent(rest, count - 1)
  end

  defp strip_leading_indent(s, _) do
    s
  end

  defp maybe_trim(iodata, [?t]) do
    iodata
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
  end

  defp maybe_trim(iodata, _) do
    IO.iodata_to_binary(iodata)
  end
end
