defmodule ElixirLS.LanguageServer.SourceFile do
  import ElixirLS.LanguageServer.Protocol

  defstruct [:text, :version, dirty?: false]

  def lines(%__MODULE__{text: text}) do
    lines(text)
  end

  def lines(text) when is_binary(text) do
    String.split(text, ["\r\n", "\r", "\n"])
  end

  def apply_content_changes(source_file, []) do
    source_file
  end

  def apply_content_changes(source_file, [edit | rest]) do
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
  def path_from_uri(uri) do
    uri_path = URI.decode(URI.parse(uri).path)

    case :os.type() do
      {:win32, _} -> String.trim_leading(uri_path, "/")
      _ -> uri_path
    end
  end

  def path_to_uri(path) do
    uri_path =
      path
      |> Path.expand()
      |> URI.encode()
      |> String.replace(":", "%3A")

    case :os.type() do
      {:win32, _} -> "file:///" <> uri_path
      _ -> "file://" <> uri_path
    end
  end

  def full_range(source_file) do
    lines = lines(source_file)

    %{
      "start" => %{"line" => 0, "character" => 0},
      "end" => %{"line" => Enum.count(lines) - 1, "character" => String.length(List.last(lines))}
    }
  end

  def apply_edit(text, range(start_line, start_character, end_line, end_character), new_text) do
    lines_with_idx =
      text
      |> lines()
      |> Enum.with_index()

    acc =
      Enum.reduce(lines_with_idx, [], fn {line, idx}, acc ->
        cond do
          idx < start_line ->
            [[line, ?\n] | acc]

          idx == start_line ->
            [String.slice(line, 0, start_character) | acc]

          idx > start_line ->
            acc
        end
      end)

    acc = [new_text | acc]

    acc =
      Enum.reduce(lines_with_idx, acc, fn {line, idx}, acc ->
        cond do
          idx < end_line ->
            acc

          idx == end_line ->
            [[String.slice(line, end_character..-1), ?\n] | acc]

          idx > end_line ->
            [[line, ?\n] | acc]
        end
      end)

    # Remove extraneous newline from last line
    [[last_line, ?\n] | rest] = acc
    acc = [last_line | rest]

    IO.iodata_to_binary(Enum.reverse(acc))
  end

  def module_line(module) do
    # TODO: Don't call into here directly
    case ElixirSense.Core.Normalized.Code.get_docs(module, :moduledoc) do
      nil ->
        nil

      {line, _} ->
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
          {{^fun, ^arity}, line, _, _, _} -> line
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
end
