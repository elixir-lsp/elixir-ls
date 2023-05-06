defmodule ElixirLS.Test.CodeMod.Case do
  alias LSP.Types.TextDocument.ContentChangeEvent.TextDocumentContentChangeEvent,
    as: RangedContentChangeEvent

  alias ElixirLS.LanguageServer.Experimental.SourceFile

  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__), only: [sigil_q: 2]

      def apply_code_mod(_, _, _) do
        {:error, "You must implement apply_code_mod/3"}
      end

      defoverridable apply_code_mod: 3

      def modify(original, options \\ []) do
        with {:ok, ast} <- maybe_convert_to_ast(original, options),
             {:ok, edits} <- apply_code_mod(original, ast, options) do
          {:ok, unquote(__MODULE__).apply_edits(original, edits, options)}
        end
      end

      defp maybe_convert_to_ast(code, options) do
        alias ElixirLS.LanguageServer.Experimental.CodeMod.Ast

        if Keyword.get(options, :convert_to_ast, true) do
          Ast.from(code)
        else
          {:ok, nil}
        end
      end
    end
  end

  def sigil_q(text, opts \\ []) do
    ["", first | rest] = text |> String.split("\n")
    base_indent = indent(first)
    indent_length = String.length(base_indent)

    Enum.map_join([first | rest], "\n", &strip_leading_indent(&1, indent_length))
    |> maybe_trim(opts)
  end

  def apply_edits(original, text_edits, opts) do
    source_file = SourceFile.new("file:///file.ex", original, 0)

    converted_edits =
      Enum.map(text_edits, fn edit ->
        RangedContentChangeEvent.new(text: edit.new_text, range: edit.range)
      end)

    {:ok, edited_source_file} = SourceFile.apply_content_changes(source_file, 1, converted_edits)
    edited_source = SourceFile.to_string(edited_source_file)

    if Keyword.get(opts, :trim, true) do
      String.trim(edited_source)
    else
      edited_source
    end
  end

  defp maybe_trim(iodata, [?t]) do
    iodata
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
  end

  defp maybe_trim(iodata, _) do
    IO.iodata_to_binary(iodata)
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
end
