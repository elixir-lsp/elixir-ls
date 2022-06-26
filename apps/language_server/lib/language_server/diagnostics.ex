defmodule ElixirLS.LanguageServer.Diagnostics do
  alias ElixirLS.LanguageServer.{SourceFile, JsonRpc}
  alias ElixirLS.Utils.MixfileHelpers

  def normalize(diagnostics, root_path) do
    for diagnostic <- diagnostics do
      {type, file, line, description, stacktrace} =
        extract_message_info(diagnostic.message, root_path)

      diagnostic
      |> update_message(type, description, stacktrace)
      |> maybe_update_file(file)
      |> maybe_update_position(type, line, stacktrace)
    end
  end

  defp extract_message_info(list, root_path) when is_list(list) do
    list
    |> Enum.join()
    |> extract_message_info(root_path)
  end

  defp extract_message_info(diagnostic_message, root_path) do
    {reversed_stacktrace, reversed_description} =
      diagnostic_message
      |> String.trim_trailing()
      |> SourceFile.lines()
      |> Enum.reverse()
      |> Enum.split_while(&is_stack?/1)

    message = reversed_description |> Enum.reverse() |> Enum.join("\n") |> String.trim()
    stacktrace = reversed_stacktrace |> Enum.map(&String.trim/1) |> Enum.reverse()

    {type, message_without_type} = split_type_and_message(message)
    {file, line, description} = split_file_and_description(message_without_type, root_path)

    {type, file, line, description, stacktrace}
  end

  defp update_message(diagnostic, type, description, stacktrace) do
    description =
      if type do
        "(#{type}) #{description}"
      else
        description
      end

    message =
      if stacktrace != [] do
        stacktrace =
          stacktrace
          |> Enum.map_join("\n", &"  │ #{&1}")
          |> String.trim_trailing()

        description <> "\n\n" <> "Stacktrace:\n" <> stacktrace
      else
        description
      end

    Map.put(diagnostic, :message, message)
  end

  defp maybe_update_file(diagnostic, path) do
    if path do
      Map.put(diagnostic, :file, path)
    else
      diagnostic
    end
  end

  defp maybe_update_position(diagnostic, "TokenMissingError", line, stacktrace) do
    case extract_line_from_missing_hint(diagnostic.message) do
      line when is_integer(line) ->
        %{diagnostic | position: line}

      _ ->
        do_maybe_update_position(diagnostic, line, stacktrace)
    end
  end

  defp maybe_update_position(diagnostic, _type, line, stacktrace) do
    do_maybe_update_position(diagnostic, line, stacktrace)
  end

  defp do_maybe_update_position(diagnostic, line, stacktrace) do
    cond do
      line ->
        %{diagnostic | position: line}

      diagnostic.position ->
        diagnostic

      true ->
        line = extract_line_from_stacktrace(diagnostic.file, stacktrace)
        %{diagnostic | position: line}
    end
  end

  defp split_type_and_message(message) do
    case Regex.run(~r/^\*\* \(([\w\.]+?)?\) (.*)/s, message) do
      [_, type, rest] ->
        {type, rest}

      _ ->
        {nil, message}
    end
  end

  defp split_file_and_description(message, root_path) do
    with {file, line, _column, description} <- get_message_parts(message),
         {:ok, path} <- file_path(file, root_path) do
      {path, String.to_integer(line), description}
    else
      _ ->
        {nil, nil, message}
    end
  end

  defp get_message_parts(message) do
    case Regex.run(~r/^(.*?):(\d+)(:(\d+))?: (.*)/s, message) do
      [_, file, line, _, column, description] -> {file, line, column, description}
      _ -> nil
    end
  end

  defp file_path(file, root_path) do
    path = Path.join([root_path, file])

    if File.exists?(path, [:raw]) do
      {:ok, path}
    else
      file_path_in_umbrella(file, root_path)
    end
  end

  defp file_path_in_umbrella(file, root_path) do
    case [root_path, "apps", "*", file] |> Path.join() |> Path.wildcard() do
      [] ->
        {:error, :file_not_found}

      [path] ->
        {:ok, path}

      _ ->
        {:error, :more_than_one_file_found}
    end
  end

  defp is_stack?("    " <> str) do
    Regex.match?(~r/.*\.(ex|erl):\d+: /, str) ||
      Regex.match?(~r/.*expanding macro: /, str)
  end

  defp is_stack?(_) do
    false
  end

  defp extract_line_from_missing_hint(message) do
    case Regex.run(
           ~r/HINT: it looks like the .+ on line (\d+) does not have a matching /,
           message
         ) do
      [_, line] -> String.to_integer(line)
      _ -> nil
    end
  end

  defp extract_line_from_stacktrace(file, stacktrace) do
    Enum.find_value(stacktrace, fn stack_item ->
      with [_, _, file_relative, line] <-
             Regex.run(~r/(\(.+?\)\s+)?(.*\.ex):(\d+): /, stack_item),
           true <- String.ends_with?(file, file_relative) do
        String.to_integer(line)
      else
        _ ->
          nil
      end
    end)
  end

  def publish_file_diagnostics(uri, all_diagnostics, source_file) do
    diagnostics =
      all_diagnostics
      |> Enum.filter(&(SourceFile.path_to_uri(&1.file) == uri))
      |> Enum.sort_by(fn %{position: position} -> position end)

    diagnostics_json =
      for diagnostic <- diagnostics do
        severity =
          case diagnostic.severity do
            :error -> 1
            :warning -> 2
            :information -> 3
            :hint -> 4
          end

        message =
          case diagnostic.message do
            m when is_binary(m) -> m
            m when is_list(m) -> m |> Enum.join("\n")
          end

        %{
          "message" => message,
          "severity" => severity,
          "range" => range(diagnostic.position, source_file),
          "source" => diagnostic.compiler_name
        }
      end

    JsonRpc.notify("textDocument/publishDiagnostics", %{
      "uri" => uri,
      "diagnostics" => diagnostics_json
    })
  end

  def mixfile_diagnostic({file, line, message}, severity) do
    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: file,
      position: line,
      message: message,
      severity: severity
    }
  end

  def exception_to_diagnostic(error) do
    msg =
      case error do
        {:shutdown, 1} ->
          "Build failed for unknown reason. See output log."

        _ ->
          Exception.format_exit(error)
      end

    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: Path.absname(MixfileHelpers.mix_exs()),
      # 0 means unknown
      position: 0,
      message: msg,
      severity: :error,
      details: error
    }
  end

  # for details see
  # https://hexdocs.pm/mix/1.13.4/Mix.Task.Compiler.Diagnostic.html#t:position/0
  # https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/#diagnostic

  # position is a 1 based line number
  # we return a range of trimmed text in that line
  defp range(position, source_file)
       when is_integer(position) and position >= 1 and not is_nil(source_file) do
    # line is 1 based
    line = position - 1
    text = Enum.at(SourceFile.lines(source_file), line) || ""

    start_idx = String.length(text) - String.length(String.trim_leading(text)) + 1
    length = max(String.length(String.trim(text)), 1)

    %{
      "start" => %{
        "line" => line,
        "character" => SourceFile.elixir_character_to_lsp(text, start_idx)
      },
      "end" => %{
        "line" => line,
        "character" => SourceFile.elixir_character_to_lsp(text, start_idx + length)
      }
    }
  end

  # position is a 1 based line number and 0 based character cursor (UTF8)
  # we return a 0 length range exactly at that location
  defp range({line_start, char_start}, source_file)
       when line_start >= 1 and not is_nil(source_file) do
    lines = SourceFile.lines(source_file)
    # line is 1 based
    start_line = Enum.at(lines, line_start - 1)
    # SourceFile.elixir_character_to_lsp assumes char to be 1 based but it's 0 based bere
    character = SourceFile.elixir_character_to_lsp(start_line, char_start + 1)

    %{
      "start" => %{
        "line" => line_start - 1,
        "character" => character
      },
      "end" => %{
        "line" => line_start - 1,
        "character" => character
      }
    }
  end

  # position is a range defined by 1 based line numbers and 0 based character cursors (UTF8)
  # we return exactly that range
  defp range({line_start, char_start, line_end, char_end}, source_file)
       when line_start >= 1 and line_end >= 1 and not is_nil(source_file) do
    lines = SourceFile.lines(source_file)
    # line is 1 based
    start_line = Enum.at(lines, line_start - 1)
    end_line = Enum.at(lines, line_end - 1)

    # SourceFile.elixir_character_to_lsp assumes char to be 1 based but it's 0 based bere
    start_char = SourceFile.elixir_character_to_lsp(start_line, char_start + 1)
    end_char = SourceFile.elixir_character_to_lsp(end_line, char_end + 1)

    %{
      "start" => %{
        "line" => line_start - 1,
        "character" => start_char
      },
      "end" => %{
        "line" => line_end - 1,
        "character" => end_char
      }
    }
  end

  # position is 0 which means unknown
  # we return the full file range
  defp range(0, source_file) when not is_nil(source_file) do
    SourceFile.full_range(source_file)
  end

  # source file is unknown
  # we discard any position information as it is meaningless
  # unfortunately LSP does not allow `null` range so we need to return something
  defp range(_, nil) do
    # we don't care about utf16 positions here as we send 0
    %{"start" => %{"line" => 0, "character" => 0}, "end" => %{"line" => 0, "character" => 0}}
  end
end
