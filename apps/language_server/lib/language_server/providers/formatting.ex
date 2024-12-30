defmodule ElixirLS.LanguageServer.Providers.Formatting do
  import ElixirLS.LanguageServer.Protocol, only: [range: 4]
  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.JsonRpc
  require Logger

  def format(%SourceFile{} = source_file, uri = "file:" <> _, project_dir, mix_project?)
      when is_binary(project_dir) do
    file_path = SourceFile.Path.absolute_from_uri(uri, project_dir)
    # file_path and project_dir are absolute paths with universal separators
    if SourceFile.Path.path_in_dir?(file_path, project_dir) do
      # file in project_dir we find formatter and options for file
      case SourceFile.formatter_for(uri, project_dir, mix_project?) do
        {:ok, {formatter, opts}} ->
          formatter_exs_dir = opts[:root]

          if should_format?(uri, formatter_exs_dir, opts[:inputs], project_dir) do
            do_format(source_file, formatter, opts)
          else
            JsonRpc.show_message(
              :info,
              "File #{file_path} not included in #{Path.join(formatter_exs_dir, ".formatter.exs")}"
            )

            {:ok, []}
          end

        {:error, :project_not_loaded} ->
          JsonRpc.show_message(
            :error,
            "Unable to find formatter for #{file_path}: Mix project is not loaded"
          )

          {:ok, []}

        {:error, message} ->
          JsonRpc.show_message(
            :error,
            "Unable to find formatter for #{file_path}: #{inspect(message)}"
          )

          {:ok, []}
      end
    else
      # if file is outside project_dir we format with default options
      do_format(source_file, nil, [])
    end
  end

  # if project_dir is not set or schema is not file we format with default options
  def format(%SourceFile{} = source_file, _uri, _project_dir, _mix_project?) do
    do_format(source_file, nil, [])
  end

  defp do_format(%SourceFile{text: text}, formatter, opts) do
    formatted = get_formatted(text, formatter, opts)

    response =
      text
      |> String.myers_difference(formatted)
      |> myers_diff_to_text_edits()

    {:ok, response}
  rescue
    e ->
      JsonRpc.show_message(:error, "Unable to format:\n#{Exception.message(e)}")
      {:ok, []}
  end

  defp get_formatted(text, formatter, _) when is_function(formatter) do
    formatter.(text)
  end

  defp get_formatted(text, _, opts) do
    IO.iodata_to_binary([Code.format_string!(text, opts), ?\n])
  end

  defp should_format?(file_uri, formatter_exs_dir, inputs, project_dir) when is_list(inputs) do
    file_path = SourceFile.Path.absolute_from_uri(file_uri, project_dir)

    Enum.any?(inputs, fn input_glob ->
      try do
        glob = Path.join(formatter_exs_dir, input_glob)
        PathGlobVendored.match?(file_path, glob, match_dot: true)
      rescue
        error ->
          # Path.join crashes in case there is junk in input
          error_msg = Exception.format(:error, error, __STACKTRACE__)

          Logger.error(
            "Unable to expand .formatter.exs input #{inspect(input_glob)}: #{error_msg}"
          )

          false
      end
    end)
  end

  defp should_format?(_file_uri, _formatter_exs_dir, _inputs, _project_dir), do: true

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
