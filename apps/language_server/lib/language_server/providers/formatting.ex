defmodule ElixirLS.LanguageServer.Providers.Formatting do
  import ElixirLS.LanguageServer.Protocol, only: [range: 4]
  alias ElixirLS.LanguageServer.SourceFile

  def supported? do
    function_exported?(Code, :format_string!, 2)
  end

  def format(source_file, uri, project_dir) do
    if can_format?(uri, project_dir) do
      file = SourceFile.path_from_uri(uri) |> Path.relative_to(project_dir)
      opts = formatter_opts(file)
      formatted = IO.iodata_to_binary([Code.format_string!(source_file.text, opts), ?\n])

      response =
        source_file.text
        |> String.myers_difference(formatted)
        |> myers_diff_to_text_edits()

      {:ok, response}
    else
      msg =
        "Cannot format file from current directory " <>
          "(Currently in #{Path.relative_to(File.cwd!(), project_dir)})"

      {:error, :internal_error, msg}
    end
  rescue
    _e in [TokenMissingError, SyntaxError] ->
      {:error, :internal_error, "Unable to format due to syntax error"}
  end

  # If in an umbrella project, the cwd might be set to a sub-app if it's being compiled. This is
  # fine if the file we're trying to format is in that app. Otherwise, we return an error.
  defp can_format?(file_uri, project_dir) do
    project_dir = project_dir |> String.downcase()
    file_path = file_uri |> SourceFile.path_from_uri() |> String.downcase()
    cwd = File.cwd!() |> String.downcase()

    not String.starts_with?(file_path, project_dir) or
      String.starts_with?(Path.absname(file_path), cwd)
  end

  defp formatter_opts(for_file) do
    Mix.Tasks.Format.formatter_opts_for_file(for_file)
  end

  defp myers_diff_to_text_edits(myers_diff, starting_pos \\ {0, 0}) do
    myers_diff_to_text_edits(myers_diff, starting_pos, [])
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
      if char == "\n" do
        {line + 1, 0}
      else
        {line, col + 1}
      end
    end)
  end
end
