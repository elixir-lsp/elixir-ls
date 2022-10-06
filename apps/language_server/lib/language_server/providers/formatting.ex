defmodule ElixirLS.LanguageServer.Providers.Formatting do
  import ElixirLS.LanguageServer.Protocol, only: [range: 4]
  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.SourceFile

  def format(%SourceFile{} = source_file, uri = "file:" <> _, project_dir)
      when is_binary(project_dir) do
    if can_format?(uri, project_dir) do
      case SourceFile.formatter_for(uri) do
        {:ok, {formatter, opts}} ->
          if should_format?(uri, project_dir, opts[:inputs]) do
            do_format(source_file, formatter, opts)
          else
            {:ok, []}
          end

        {:ok, opts} ->
          if should_format?(uri, project_dir, opts[:inputs]) do
            do_format(source_file, opts)
          else
            {:ok, []}
          end

        :error ->
          {:error, :internal_error, "Unable to fetch formatter options"}
      end
    else
      msg =
        "Cannot format file from current directory " <>
          "(Currently in #{Path.relative_to(File.cwd!(), project_dir)})"

      {:error, :internal_error, msg}
    end
  end

  # if project_dir is not set or schema is not file: we format with default options
  def format(%SourceFile{} = source_file, _uri, _project_dir) do
    do_format(source_file)
  end

  defp do_format(%SourceFile{} = source_file, opts \\ []), do: do_format(source_file, nil, opts)

  defp do_format(%SourceFile{text: text}, formatter, opts) do
    formatted = get_formatted(text, formatter, opts)

    response =
      text
      |> String.myers_difference(formatted)
      |> myers_diff_to_text_edits()

    {:ok, response}
  rescue
    _e in [TokenMissingError, SyntaxError] ->
      {:error, :internal_error, "Unable to format due to syntax error"}
  end

  defp get_formatted(text, formatter, _) when is_function(formatter) do
    formatter.(text)
  end

  defp get_formatted(text, _, opts) do
    IO.iodata_to_binary([Code.format_string!(text, opts), ?\n])
  end

  # If in an umbrella project, the cwd might be set to a sub-app if it's being compiled. This is
  # fine if the file we're trying to format is in that app. Otherwise, we return an error.
  defp can_format?(file_uri = "file:" <> _, project_dir) do
    file_path = SourceFile.Path.absolute_from_uri(file_uri)

    String.starts_with?(file_path, Path.absname(project_dir)) or
      String.starts_with?(file_path, File.cwd!())
  end

  defp can_format?(_uri, _project_dir), do: false

  defp should_format?(file_uri, project_dir, inputs) when is_list(inputs) do
    file_path = SourceFile.Path.absolute_from_uri(file_uri)
    formatter_dir = find_formatter_dir(project_dir, Path.dirname(file_path))

    Enum.any?(inputs, fn input_glob ->
      glob = Path.join(formatter_dir, input_glob)
      PathGlobVendored.match?(file_path, glob, match_dot: true)
    end)
  end

  defp should_format?(_file_uri, _project_dir, _inputs), do: true

  # Finds the deepest directory that contains file_path, that also contains a
  # .formatter.exs. It's possible, though unlikely, that the .formatter.exs we
  # find is not actually linked to the project_dir via the :subdirectories
  # option in the top-level .formatter.exs. Currently, that edge case is
  # glossed over.
  defp find_formatter_dir(project_dir, dir) do
    cond do
      dir == project_dir ->
        project_dir

      Path.join(dir, ".formatter.exs") |> File.exists?() ->
        dir

      true ->
        find_formatter_dir(project_dir, Path.dirname(dir))
    end
  end

  defp myers_diff_to_text_edits(myers_diff) do
    myers_diff_to_text_edits(myers_diff, {0, 0}, [])
  end

  defp myers_diff_to_text_edits([], _pos, edits) do
    edits
  end

  defp myers_diff_to_text_edits([diff | rest], {line, col}, edits) do
    case {diff, rest} do
      {{:eq, str}, _} ->
        myers_diff_to_text_edits(rest, advance_pos({line, col}, str), edits)

      {{:ins, str}, _} ->
        edit = %TextEdit{range: range(line, col, line, col), newText: str}
        myers_diff_to_text_edits(rest, {line, col}, [edit | edits])

      {{:del, del_str}, [{:ins, ins_str} | rest]} ->
        {end_line, end_col} = advance_pos({line, col}, del_str)
        edit = %TextEdit{range: range(line, col, end_line, end_col), newText: ins_str}
        myers_diff_to_text_edits(rest, {end_line, end_col}, [edit | edits])

      {{:del, str}, _} ->
        {end_line, end_col} = advance_pos({line, col}, str)
        edit = %TextEdit{range: range(line, col, end_line, end_col), newText: ""}
        myers_diff_to_text_edits(rest, {end_line, end_col}, [edit | edits])
    end
  end

  defp advance_pos({line, col}, str) do
    Enum.reduce(String.split(str, "", trim: true), {line, col}, fn char, {line, col} ->
      if char in ["\r\n", "\n", "\r"] do
        {line + 1, 0}
      else
        # LSP contentChanges positions are based on UTF-16 string representation
        # https://microsoft.github.io/language-server-protocol/specification#textDocuments
        {line, col + div(byte_size(:unicode.characters_to_binary(char, :utf8, :utf16)), 2)}
      end
    end)
  end
end
