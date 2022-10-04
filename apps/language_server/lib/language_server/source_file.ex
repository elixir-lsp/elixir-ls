defmodule ElixirLS.LanguageServer.SourceFile do
  import ElixirLS.LanguageServer.Protocol

  defstruct [:text, :version, dirty?: false]

  @endings ["\r\n", "\r", "\n"]

  def lines(%__MODULE__{text: text}) do
    lines(text)
  end

  def lines(text) when is_binary(text) do
    String.split(text, @endings)
  end

  @doc """
  Takes text and splits it into lines, return each line as a tuple with the line
  and the line-ending. Needed because the LSP spec requires us to preserve the
  used line endings.
  """
  def lines_with_endings(text) do
    do_lines_with_endings(text, "")
  end

  def do_lines_with_endings("", line) when is_binary(line) do
    [{line, nil}]
  end

  for line_ending <- @endings do
    def do_lines_with_endings(<<unquote(line_ending), rest::binary>>, line)
        when is_binary(line) do
      [{line, unquote(line_ending)} | do_lines_with_endings(rest, "")]
    end
  end

  def do_lines_with_endings(<<char::utf8, rest::binary>>, line) when is_binary(line) do
    do_lines_with_endings(rest, line <> <<char::utf8>>)
  end

  def apply_content_changes(%__MODULE__{} = source_file, []) do
    source_file
  end

  def apply_content_changes(%__MODULE__{} = source_file, [edit | rest]) do
    source_file =
      case edit do
        %{"range" => edited_range, "text" => new_text} when not is_nil(edited_range) ->
          update_in(source_file.text, fn text ->
            apply_edit(text, edited_range, new_text)
          end)

        %{"text" => new_text} ->
          put_in(source_file.text, new_text)
      end

    source_file =
      update_in(source_file.version, fn
        v when is_integer(v) -> v + 1
        _ -> 1
      end)

    apply_content_changes(source_file, rest)
  end

  @doc """
  Returns path from URI in a way that handles windows file:///c%3A/... URLs correctly
  """
  def path_from_uri(%URI{scheme: "file", path: path, authority: authority}) do
    uri_path =
      cond do
        path == nil ->
          # treat no path as root path
          "/"

        authority not in ["", nil] and path not in ["", nil] ->
          # UNC path
          "//#{URI.decode(authority)}#{URI.decode(path)}"

        true ->
          decoded_path = URI.decode(path)

          if match?({:win32, _}, :os.type()) and
               String.match?(decoded_path, ~r/^\/[a-zA-Z]:/) do
            # Windows drive letter path
            # drop leading `/` and downcase drive letter
            <<_, letter, path_rest::binary>> = decoded_path
            <<downcase(letter), path_rest::binary>>
          else
            decoded_path
          end
      end

    case :os.type() do
      {:win32, _} ->
        # convert path separators from URI to Windows
        String.replace(uri_path, ~r/\//, "\\")

      _ ->
        uri_path
    end
  end

  def path_from_uri(%URI{scheme: scheme}) do
    raise ArgumentError, message: "unexpected URI scheme #{inspect(scheme)}"
  end

  def path_from_uri(uri) do
    uri |> URI.parse() |> path_from_uri
  end

  def path_to_uri(path) do
    path = Path.expand(path)

    path =
      case :os.type() do
        {:win32, _} ->
          # convert path separators from Windows to URI
          String.replace(path, ~r/\\/, "/")

        _ ->
          path
      end

    {authority, path} =
      case path do
        "//" <> rest ->
          # UNC path - extract authority
          case String.split(rest, "/", parts: 2) do
            [_] ->
              # no path part, use root path
              {rest, "/"}

            [a, ""] ->
              # empty path part, use root path
              {a, "/"}

            [a, p] ->
              {a, "/" <> p}
          end

        "/" <> _rest ->
          {"", path}

        other ->
          # treat as relative to root path
          {"", "/" <> other}
      end

    %URI{
      scheme: "file",
      authority: authority |> URI.encode(),
      # file system paths allow reserved URI characters that need to be escaped
      # the exact rules are complicated but for simplicity we escape all reserved except `/`
      # that's what https://github.com/microsoft/vscode-uri does
      path: path |> URI.encode(&(&1 == ?/ or URI.char_unreserved?(&1)))
    }
    |> URI.to_string()
  end

  defp downcase(char) when char >= ?A and char <= ?Z, do: char + 32
  defp downcase(char), do: char

  def abs_path_from_uri(uri) do
    uri |> path_from_uri |> Path.absname()
  end

  def full_range(source_file) do
    lines = lines(source_file)

    utf16_size =
      lines
      |> List.last()
      |> line_length_utf16()

    range(0, 0, Enum.count(lines) - 1, utf16_size)
  end

  def line_length_utf16(line) do
    line
    |> characters_to_binary!(:utf8, :utf16)
    |> byte_size()
    |> div(2)
  end

  defp prepend_line(line, nil, acc) when is_binary(line), do: [line | acc]

  defp prepend_line(line, ending, acc) when is_binary(line) and ending in @endings,
    do: [[line, ending] | acc]

  def apply_edit(text, range(start_line, start_character, end_line, end_character), new_text) do
    lines_with_idx =
      text
      |> lines_with_endings()
      |> Enum.with_index()

    acc =
      Enum.reduce(lines_with_idx, [], fn {{line, ending}, idx}, acc ->
        cond do
          idx < start_line ->
            prepend_line(line, ending, acc)

          idx == start_line ->
            # LSP contentChanges positions are based on UTF-16 string representation
            # https://microsoft.github.io/language-server-protocol/specification#textDocuments
            beginning_utf8 =
              characters_to_binary!(line, :utf8, :utf16)
              |> (&binary_part(
                    &1,
                    0,
                    min(start_character * 2, byte_size(&1))
                  )).()
              |> characters_to_binary!(:utf16, :utf8)

            [beginning_utf8 | acc]

          idx > start_line ->
            acc
        end
      end)

    acc = [new_text | acc]

    acc =
      Enum.reduce(lines_with_idx, acc, fn {{line, ending}, idx}, acc ->
        cond do
          idx < end_line ->
            acc

          idx == end_line ->
            # LSP contentChanges positions are based on UTF-16 string representation
            # https://microsoft.github.io/language-server-protocol/specification#textDocuments
            ending_utf8 =
              characters_to_binary!(line, :utf8, :utf16)
              |> (&binary_part(
                    &1,
                    min(end_character * 2, byte_size(&1)),
                    max(byte_size(&1) - end_character * 2, 0)
                  )).()
              |> characters_to_binary!(:utf16, :utf8)

            prepend_line(ending_utf8, ending, acc)

          idx > end_line ->
            prepend_line(line, ending, acc)
        end
      end)

    IO.iodata_to_binary(Enum.reverse(acc))
  end

  defp characters_to_binary!(binary, from, to) do
    case :unicode.characters_to_binary(binary, from, to) do
      result when is_binary(result) -> result
    end
  end

  def module_line(module) do
    # TODO: Don't call into here directly
    case ElixirSense.Core.Normalized.Code.get_docs(module, :moduledoc) do
      nil ->
        nil

      {line, _docs, _metadata} ->
        line
    end
  end

  def function_line(mod, fun, arity) do
    # TODO: Don't call into here directly
    case ElixirSense.Core.Normalized.Code.get_docs(mod, :docs) do
      nil ->
        nil

      docs ->
        Enum.find_value(docs, fn
          {{^fun, ^arity}, line, _, _, _, _metadata} -> line
          _ -> nil
        end)
    end
  end

  def function_def_on_line?(text, line, fun) do
    case Enum.at(lines(text), line - 1) do
      nil ->
        false

      line_text ->
        # when function line is taken from docs the line points to `@doc` attribute
        # or first `def`/`defp`/`defmacro`/`defmacrop`/`defguard`/`defguardp`/`defdelegate` clause line if no `@doc` attribute
        Regex.match?(
          Regex.compile!(
            "^\s*def((macro)|(guard)|(delegate))?p?\s+#{Regex.escape(to_string(fun))}"
          ),
          line_text
        ) or
          Regex.match?(Regex.compile!("^\s*@doc"), line_text)
    end
  end

  @spec strip_macro_prefix({atom, non_neg_integer}) :: {atom, non_neg_integer}
  def strip_macro_prefix({function, arity}) do
    case Atom.to_string(function) do
      "MACRO-" <> rest -> {String.to_atom(rest), arity - 1}
      _other -> {function, arity}
    end
  end

  @spec format_spec(String.t(), keyword()) :: String.t()
  def format_spec(spec, _opts) when spec in [nil, ""] do
    ""
  end

  def format_spec(spec, opts) do
    line_length = Keyword.fetch!(opts, :line_length)

    spec_str =
      case format_code(spec, line_length: line_length) do
        {:ok, code} ->
          code
          |> to_string()
          |> lines()
          |> remove_indentation(String.length("@spec "))
          |> Enum.join("\n")

        {:error, _} ->
          spec
      end

    """

    ```
    #{spec_str}
    ```
    """
  end

  @spec formatter_for(String.t()) :: {:ok, keyword()} | :error
  def formatter_for(uri = "file:" <> _) do
    path = path_from_uri(uri)

    try do
      true = Code.ensure_loaded?(Mix.Tasks.Format)

      if function_exported?(Mix.Tasks.Format, :formatter_for_file, 1) do
        {:ok, Mix.Tasks.Format.formatter_for_file(path)}
      else
        {:ok, {nil, Mix.Tasks.Format.formatter_opts_for_file(path)}}
      end
    rescue
      e ->
        message = Exception.message(e)
        IO.warn(
          "Unable to get formatter options for #{path}: #{inspect(e.__struct__)} #{message}"
        )

        :error
    end
  end

  def formatter_for(_), do: :error

  defp format_code(code, opts) do
    try do
      {:ok, Code.format_string!(code, opts)}
    rescue
      e ->
        {:error, e}
    end
  end

  defp remove_indentation([line | rest], length) do
    [line | Enum.map(rest, &String.slice(&1, length..-1))]
  end

  defp remove_indentation(lines, _), do: lines

  def lsp_character_to_elixir(_utf8_line, lsp_character) when lsp_character <= 0, do: 1

  def lsp_character_to_elixir(utf8_line, lsp_character) do
    utf16_line =
      utf8_line
      |> characters_to_binary!(:utf8, :utf16)

    byte_size = byte_size(utf16_line)

    # if character index is over the length of the string assume we pad it with spaces (1 byte in utf8)
    diff = div(max(lsp_character * 2 - byte_size, 0), 2)

    utf8_character =
      utf16_line
      |> (&binary_part(
            &1,
            0,
            min(lsp_character * 2, byte_size)
          )).()
      |> characters_to_binary!(:utf16, :utf8)
      |> String.length()

    utf8_character + 1 + diff
  end

  def lsp_position_to_elixir(_urf8_text, {lsp_line, lsp_character}) when lsp_character <= 0,
    do: {max(lsp_line + 1, 1), 1}

  def lsp_position_to_elixir(urf8_text, {lsp_line, lsp_character}) do
    utf8_character =
      lines(urf8_text)
      |> Enum.at(max(lsp_line, 0))
      |> lsp_character_to_elixir(lsp_character)

    {lsp_line + 1, utf8_character}
  end

  def elixir_character_to_lsp(_utf8_line, elixir_character) when elixir_character <= 1, do: 0

  def elixir_character_to_lsp(utf8_line, elixir_character) do
    utf8_line
    |> String.slice(0..(elixir_character - 2))
    |> characters_to_binary!(:utf8, :utf16)
    |> byte_size()
    |> div(2)
  end

  def elixir_position_to_lsp(_urf8_text, {elixir_line, elixir_character})
      when elixir_character <= 1,
      do: {max(elixir_line - 1, 0), 0}

  def elixir_position_to_lsp(urf8_text, {elixir_line, elixir_character}) do
    utf16_character =
      lines(urf8_text)
      |> Enum.at(max(elixir_line - 1, 0))
      |> elixir_character_to_lsp(elixir_character)

    {elixir_line - 1, utf16_character}
  end
end
