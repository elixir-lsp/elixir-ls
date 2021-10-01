defmodule ElixirLS.LanguageServer.Providers.Formatting do
  import ElixirLS.LanguageServer.Protocol, only: [range: 4]
  alias ElixirLS.LanguageServer.SourceFile

  def format(%SourceFile{} = source_file, uri, project_dir) when is_binary(project_dir) do
    if can_format?(uri, project_dir) do
      case SourceFile.formatter_opts(uri) do
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

  def format(%SourceFile{} = source_file, _uri, nil) do
    do_format(source_file)
  end

  defp do_format(%SourceFile{text: text}, opts \\ []) do
    formatted = IO.iodata_to_binary([Code.format_string!(text, opts), ?\n])

    response =
      text
      |> String.myers_difference(formatted)
      |> myers_diff_to_text_edits()

    {:ok, response}
  rescue
    _e in [TokenMissingError, SyntaxError] ->
      {:error, :internal_error, "Unable to format due to syntax error"}
  end

  # If in an umbrella project, the cwd might be set to a sub-app if it's being compiled. This is
  # fine if the file we're trying to format is in that app. Otherwise, we return an error.
  defp can_format?(file_uri = "file:" <> _, project_dir) do
    file_path = file_uri |> SourceFile.abs_path_from_uri()

    String.starts_with?(file_path, Path.absname(project_dir)) or
      String.starts_with?(file_path, File.cwd!())
  end

  defp can_format?(_uri, _project_dir), do: false

  defp should_format?(file_uri, project_dir, inputs) when is_list(inputs) do
    file_path = file_uri |> SourceFile.abs_path_from_uri()

    inputs
    |> Stream.flat_map(fn glob ->
      [
        Path.join([project_dir, glob]),
        Path.join([project_dir, "apps", "*", glob])
      ]
    end)
    |> Stream.flat_map(&Path.wildcard(&1, match_dot: true))
    |> Enum.any?(&(file_path == &1))
  end

  defp should_format?(_file_uri, _project_dir, _inputs), do: true

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
        edit = %{"range" => range(line, col, line, col), "newText" => str}
        myers_diff_to_text_edits(rest, {line, col}, [edit | edits])

      {{:del, del_str}, [{:ins, ins_str} | rest]} ->
        {end_line, end_col} = advance_pos({line, col}, del_str)
        edit = %{"range" => range(line, col, end_line, end_col), "newText" => ins_str}
        myers_diff_to_text_edits(rest, {end_line, end_col}, [edit | edits])

      {{:del, str}, _} ->
        {end_line, end_col} = advance_pos({line, col}, str)
        edit = %{"range" => range(line, col, end_line, end_col), "newText" => ""}
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
