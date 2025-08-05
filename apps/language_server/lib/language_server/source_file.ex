defmodule ElixirLS.LanguageServer.SourceFile do
  alias GenLSP.Structures.TextEdit

  import ElixirLS.LanguageServer.RangeUtils
  alias ElixirLS.LanguageServer.JsonRpc
  require ElixirSense.Core.Introspection, as: Introspection
  require Logger

  @type t :: %__MODULE__{}

  defstruct [:text, :version, :language_id, dirty?: false]

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
      case normalize_text_edit(edit) do
        # GenLSP.TypeAlias.TextDocumentContentChangeEvent with range
        %{range: edited_range, text: new_text} when not is_nil(edited_range) ->
          update_in(source_file.text, fn text ->
            apply_edit(text, edited_range, new_text)
          end)

        # GenLSP.TypeAlias.TextDocumentContentChangeEvent without range
        %{text: new_text} ->
          put_in(source_file.text, new_text)
      end

    apply_content_changes(source_file, rest)
  end

  defp normalize_text_edit(%TextEdit{range: range, new_text: new_text}) do
    # return a map with the same fields as GenLSP.TypeAlias.TextDocumentContentChangeEvent
    %{range: range, text: new_text}
  end

  defp normalize_text_edit(edit) do
    edit
  end

  def full_range(source_file) do
    [_ | _] = lines = lines(source_file)

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

  def function_line(mod, fun, arity, docs \\ nil) do
    case docs || ElixirSense.Core.Normalized.Code.get_docs(mod, :docs) do
      nil ->
        nil

      docs ->
        Enum.find_value(docs, fn
          {{^fun, a}, line, _, _, _, metadata} ->
            default_args = Map.get(metadata, :defaults, 0)

            if Introspection.matches_arity_with_defaults?(a, default_args, arity) do
              line
            end

          _ ->
            nil
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

        {:error, _} ->
          spec
      end

    """

    ```elixir
    #{spec_str}
    ```
    """
  end

  @spec formatter_for(String.t(), String.t() | nil, boolean, keyword()) ::
          {:ok, {function | nil, keyword()}} | {:error, any}
  def formatter_for(uri, project_dir, mix_project?, opts \\ [])

  def formatter_for(uri = "file:" <> _, project_dir, mix_project?, opts)
      when is_binary(project_dir) do
    path = __MODULE__.Path.from_uri(uri)

    try do
      alias ElixirLS.LanguageServer.MixProjectCache

      if mix_project? do
        if MixProjectCache.loaded?() do
          {:ok, deps_paths} = MixProjectCache.deps_paths()
          {:ok, manifest_path} = MixProjectCache.manifest_path()
          {:ok, config_mtime} = MixProjectCache.config_mtime()
          {:ok, mix_project} = MixProjectCache.get()

          formatter_opts = [
            deps_paths: deps_paths,
            manifest_path: manifest_path,
            config_mtime: config_mtime,
            mix_project: mix_project,
            root: project_dir,
            plugin_loader: fn plugins ->
              for plugin <- plugins do
                cond do
                  not Code.ensure_loaded?(plugin) ->
                    JsonRpc.show_message(
                      :warning,
                      "Formatter plugin #{inspect(plugin)} is not loaded and will be skipped. Please compile the project."
                    )

                    nil

                  not function_exported?(plugin, :features, 1) ->
                    JsonRpc.show_message(
                      :error,
                      "Formatter plugin #{inspect(plugin)} does not define features/1 and will be skipped."
                    )

                    nil

                  true ->
                    plugin
                end
              end
              |> Enum.reject(&is_nil/1)

              # we don't do any plugin loading as this may trigger compile
              # TODO it may be safe to compile on 1.18+
            end
          ]

          formatter_opts =
            formatter_opts
            |> maybe_put_dot_formatter(opts)

          {:ok, Mix.Tasks.ElixirLSFormat.formatter_for_file(path, formatter_opts)}
        else
          {:error, :project_not_loaded}
        end
      else
        formatter_opts =
          [root: project_dir]
          |> maybe_put_dot_formatter(opts)

        {:ok, Mix.Tasks.ElixirLSFormat.formatter_for_file(path, formatter_opts)}
      end
    catch
      kind, payload ->
        stacktrace = __STACKTRACE__

        {payload, stacktrace} =
          try do
            Exception.blame(kind, payload, stacktrace)
          catch
            kind_1, error_1 ->
              # in case of error in Exception.blame we want to use the original error and stacktrace
              Logger.error(
                "Exception.blame failed: #{Exception.format(kind_1, error_1, __STACKTRACE__)}"
              )

              {payload, stacktrace}
          end

        message = Exception.format(kind, payload, stacktrace)

        Logger.warning("Unable to get formatter options for #{path}: #{message}")

        {:error, message}
    end
  end

  def formatter_for(_, _, _, _), do: {:error, :project_dir_not_set}

  defp maybe_put_dot_formatter(opts_list, opts) do
    dot = opts |> Keyword.get(:dot_formatter) |> to_string() |> String.trim()

    if dot != "" do
      Keyword.put(opts_list, :dot_formatter, dot)
    else
      opts_list
    end
  end

  defp format_code(code, opts) do
    try do
      {:ok, Code.format_string!(code, opts) |> IO.iodata_to_binary()}
    rescue
      e ->
        {:error, e}
    end
  end

  def lsp_character_to_elixir(_utf8_line, lsp_character) when lsp_character <= 0, do: 1

  def lsp_character_to_elixir(utf8_line, lsp_character) do
    utf16_line = characters_to_binary!(utf8_line, :utf8, :utf16)
    max_bytes = byte_size(utf16_line)

    # LSP character -> code units -> bytes
    offset0 = lsp_character * 2
    offset = clamp_offset_to_surrogate_boundary(utf16_line, offset0, max_bytes)

    partial = binary_part(utf16_line, 0, offset)
    partial_utf8 = characters_to_binary!(partial, :utf16, :utf8)
    String.length(partial_utf8) + 1
  end

  # "Clamp" helper. 
  # - If offset is out of bounds, keep it within [0, max_bytes].
  # - Then check if we landed *immediately* after a high surrogate (0xD800..0xDBFF);
  #   if so, subtract 2 to avoid slicing in the middle.
  defp clamp_offset_to_surrogate_boundary(_bin, offset, max_bytes) when offset >= max_bytes,
    do: max_bytes

  defp clamp_offset_to_surrogate_boundary(_bin, offset, _max_bytes) when offset <= 0,
    do: 0

  defp clamp_offset_to_surrogate_boundary(bin, offset, _max_bytes) when offset >= 2 do
    # We know 0 < offset < max_bytes at this point
    # Look at the 2 bytes immediately before `offset`
    prefix_offset = offset - 2
    <<_::binary-size(prefix_offset), maybe_high::binary-size(2), _::binary>> = bin
    code_unit = :binary.decode_unsigned(maybe_high, :big)

    # If that 16-bit code_unit is a high surrogate, we've sliced in half
    if code_unit in 0xD800..0xDBFF do
      prefix_offset
    else
      offset
    end
  end

  def lsp_position_to_elixir(_urf8_text_or_lines, {lsp_line, _lsp_character}) when lsp_line < 0,
    do: {1, 1}

  def lsp_position_to_elixir(_urf8_text_or_lines, {lsp_line, lsp_character})
      when lsp_character <= 0,
      do: {max(lsp_line + 1, 1), 1}

  def lsp_position_to_elixir(urf8_text, {lsp_line, lsp_character}) when is_binary(urf8_text) do
    lsp_position_to_elixir(lines(urf8_text), {lsp_line, lsp_character})
  end

  def lsp_position_to_elixir([_ | _] = urf8_lines, {lsp_line, lsp_character})
      when lsp_line >= 0 do
    total_lines = length(urf8_lines)

    if lsp_line > total_lines - 1 do
      # sanitize to position after last char in last line
      last_line = Enum.at(urf8_lines, total_lines - 1)
      elixir_last_character = String.length(last_line) + 1
      {total_lines, elixir_last_character}
    else
      line = Enum.at(urf8_lines, lsp_line)
      utf8_character = lsp_character_to_elixir(line, lsp_character)

      {lsp_line + 1, utf8_character}
    end
  end

  def elixir_character_to_lsp(_utf8_line, elixir_character) when elixir_character <= 1, do: 0

  def elixir_character_to_lsp(utf8_line, elixir_character) do
    utf8_line
    |> String.slice(0..(elixir_character - 2))
    |> characters_to_binary!(:utf8, :utf16)
    |> byte_size()
    |> div(2)
  end

  def elixir_position_to_lsp(_urf8_text_or_lines, {elixir_line, _elixir_character})
      when elixir_line < 1,
      do: {0, 0}

  def elixir_position_to_lsp(_urf8_text_or_lines, {elixir_line, elixir_character})
      when elixir_character <= 1,
      do: {max(elixir_line - 1, 0), 0}

  def elixir_position_to_lsp(urf8_text, {elixir_line, elixir_character})
      when is_binary(urf8_text) do
    elixir_position_to_lsp(lines(urf8_text), {elixir_line, elixir_character})
  end

  def elixir_position_to_lsp([_ | _] = urf8_lines, {elixir_line, elixir_character})
      when elixir_line >= 1 do
    total_lines = length(urf8_lines)

    if elixir_line > total_lines do
      # sanitize to position after last char in last line
      last_line = Enum.at(urf8_lines, total_lines - 1)
      elixir_last_character = String.length(last_line) + 1

      utf16_character = elixir_character_to_lsp(last_line, elixir_last_character)
      {total_lines - 1, utf16_character}
    else
      line = Enum.at(urf8_lines, max(elixir_line - 1, 0))
      utf16_character = elixir_character_to_lsp(line, elixir_character)

      {elixir_line - 1, utf16_character}
    end
  end
end
