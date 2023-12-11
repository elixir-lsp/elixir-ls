defmodule ElixirLS.LanguageServer.Diagnostics do
  @moduledoc """
  This module provides utility functions for normalizing diagnostics
  from various sources
  """
  alias ElixirLS.LanguageServer.{SourceFile, JsonRpc}

  def normalize(diagnostics, root_path, mixfile) do
    for %Mix.Task.Compiler.Diagnostic{} = diagnostic <- diagnostics do
      case diagnostic |> dbg do
        %Mix.Task.Compiler.Diagnostic{details: payload = %_{line: _}, compiler_name: compiler_name} ->
          # remove stacktrace
          message = Exception.format_banner(:error, payload)
          compiler_name = if compiler_name == "Elixir", do: "ElixirLS", else: compiler_name
          %Mix.Task.Compiler.Diagnostic{diagnostic | message: message, compiler_name: compiler_name}

        _ ->
          {type, file, position, stacktrace} =
            extract_message_info(diagnostic.message, root_path)

          diagnostic
          |> maybe_update_file(file, mixfile)
          |> maybe_update_position(type, position, stacktrace)
      end
    end
  end

  defp extract_message_info(diagnostic_message, root_path) do
    {reversed_stacktrace, reversed_description} =
      diagnostic_message
      |> IO.chardata_to_string()
      |> String.trim_trailing()
      |> SourceFile.lines()
      |> Enum.reverse()
      |> Enum.split_while(&is_stack?/1)

    message = reversed_description |> Enum.reverse() |> Enum.join("\n") |> String.trim()
    stacktrace = reversed_stacktrace |> Enum.map(&String.trim/1) |> Enum.reverse()

    {type, message_without_type} = split_type_and_message(message)
    {file, position} = get_file_and_position(message_without_type, root_path)

    {type, file, position, stacktrace}
  end

  defp maybe_update_file(diagnostic, path, mixfile) do
    if path do
      Map.put(diagnostic, :file, path)
    else
      if is_nil(diagnostic.file) do
        Map.put(diagnostic, :file, mixfile)
      else
        diagnostic
      end
    end
  end

  defp maybe_update_position(diagnostic, "TokenMissingError", position, stacktrace) do
    case extract_line_from_missing_hint(diagnostic.message) do
      line when is_integer(line) and line > 0 ->
        %{diagnostic | position: line}

      _ ->
        do_maybe_update_position(diagnostic, position, stacktrace)
    end
  end

  defp maybe_update_position(diagnostic, _type, position, stacktrace) do
    do_maybe_update_position(diagnostic, position, stacktrace)
  end

  defp do_maybe_update_position(diagnostic, position, stacktrace) do
    cond do
      position != nil ->
        %{diagnostic | position: position}

      diagnostic.position ->
        diagnostic

      true ->
        line = extract_line_from_stacktrace(diagnostic.file, stacktrace)
        %{diagnostic | position: max(line, 0)}
    end
  end

  defp split_type_and_message(message) do
    case Regex.run(~r/^\*\* \(([\w\.]+?)?\) (.*)/su, message) do
      [_, type, rest] ->
        {type, rest}

      _ ->
        {nil, message}
    end
  end

  defp get_file_and_position(message, root_path) do
    # this regex won't match filenames with spaces but in elixir 1.16 errors we can't be sure where
    # the file name starts e.g.
    # invalid syntax found on lib/template.eex:2:5:
    file_position =
      case Regex.run(~r/([^\s:]+):(\d+)(:(\d+))?/su, message) do
        [_, file, line] -> {file, line, ""}
        [_, file, line, _, column] -> {file, line, column}
        _ -> nil
      end

    with {file, line, column} <- file_position,
         {:ok, path} <- file_path(file, root_path) do
      line = String.to_integer(line)

      position =
        cond do
          line == 0 -> 0
          column == "" -> line
          true -> {line, String.to_integer(column)}
        end

      {path, position}
    else
      _ ->
        {nil, nil}
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
    case [
           SourceFile.Path.escape_for_wildcard(root_path),
           "apps",
           "*",
           SourceFile.Path.escape_for_wildcard(file)
         ]
         |> Path.join()
         |> Path.wildcard() do
      [] ->
        {:error, :file_not_found}

      [path] ->
        {:ok, path}

      _ ->
        {:error, :more_than_one_file_found}
    end
  end

  defp is_stack?("    " <> str) do
    Regex.match?(~r/.*\.(ex|erl):\d+: /u, str) ||
      Regex.match?(~r/.*expanding macro: /u, str)
  end

  defp is_stack?(_) do
    false
  end

  defp extract_line_from_missing_hint(message) do
    case Regex.run(
           ~r/starting at line (\d+)\)/u,
           message
         ) do
      [_, line] -> String.to_integer(line)
      _ -> nil
    end
  end

  defp extract_line_from_stacktrace(file, stacktrace) do
    Enum.find_value(stacktrace, fn stack_item ->
      with [_, _, file_relative, line] <-
             Regex.run(~r/(\(.+?\)\s+)?(.*\.ex):(\d+): /u, stack_item),
           true <- String.ends_with?(file, file_relative) do
        String.to_integer(line)
      else
        _ ->
          nil
      end
    end)
  end

  def mixfile_diagnostic({file, position, message}, severity) when not is_nil(file) do
    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: file,
      position: position,
      message: message,
      severity: severity
    }
  end

  def code_diagnostic(%{
        file: file,
        severity: severity,
        message: message,
        position: position
      })
      when not is_nil(file) do
    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: file,
      position: position,
      message: message,
      severity: severity
    }
  end

  def error_to_diagnostic(:error, %_{line: _} = payload, _stacktrace, path, project_dir) do
    path = SourceFile.Path.absname(path, project_dir)
    message = Exception.format_banner(:error, payload)

    position = case payload do
      %{line: line, column: column} -> {line, column}
      %{line: line} -> line
    end

    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: path,
      position: position,
      message: message,
      severity: :error,
      details: payload
    }
  end

  def error_to_diagnostic(kind, payload, stacktrace, path, project_dir) when not is_nil(path) do
    path = SourceFile.Path.absname(path, project_dir)
    message = Exception.format(kind, payload, stacktrace)

    line =
      stacktrace
      |> Enum.find_value(fn {_m, _f, _a, opts} ->
        file = opts |> Keyword.get(:file)

        if file != nil and SourceFile.Path.absname(file, project_dir) == path do
          opts |> Keyword.get(:line)
        end
      end)

    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: path,
      # 0 means unknown
      position: line || 0,
      message: message,
      severity: :error,
      details: payload
    }
  end

  def exception_to_diagnostic(error, path) when not is_nil(path) do
    msg =
      case error do
        {:shutdown, 1} ->
          "Build failed for unknown reason. See output log."

        _ ->
          Exception.format_exit(error)
      end

    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: path,
      # 0 means unknown
      position: 0,
      message: msg,
      severity: :error,
      details: error
    }
  end

  def publish_file_diagnostics(uri, uri_diagnostics, source_file, version) do
    diagnostics_json =
      for diagnostic <- uri_diagnostics do
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
          "source" => diagnostic.compiler_name,
          "relatedInformation" => build_related_information(diagnostic, uri, source_file),
          "tags" => get_tags(diagnostic)
        }
      end
      |> Enum.sort_by(& &1["range"]["start"])

    message = %{
      "uri" => uri,
      "diagnostics" => diagnostics_json
    }

    message =
      if is_integer(version) do
        Map.put(message, "version", version)
      else
        message
      end

    JsonRpc.notify("textDocument/publishDiagnostics", message)
  end

  defp get_tags(diagnostic) do
    unused = if Regex.match?(~r/unused|no effect/u, diagnostic.message) do
      [1]
    else
      []
    end
    deprecated = if Regex.match?(~r/deprecated/u, diagnostic.message) do
      [2]
    else
      []
    end

    unused ++ deprecated
  end

  defp get_related_information_description(description, uri, source_file) do
    line = case Regex.run(
           ~r/line (\d+)/u,
           description
         ) do
          [_, line] -> String.to_integer(line)
          _ -> nil
        end

        message = case String.split(description, "hint: ") do
          [_, hint] -> hint
          _ -> description
        end

        if line do
          [
            %{
              "location" => %{
                "uri" => uri,
                "range" => range(line, source_file)
              },
              "message" => message
            }
          ]
        else
          []
        end
  end

  defp get_related_information_message(message, uri, source_file) do
    line = case Regex.run(
           ~r/line (\d+)/u,
           message
         ) do
          [_, line] -> String.to_integer(line)
          _ -> nil
        end

        if line do
          [
            %{
              "location" => %{
                "uri" => uri,
                "range" => range(line, source_file)
              },
              "message" => "related"
            }
          ]
        else
          []
        end
  end

  defp build_related_information(diagnostic, uri, source_file) do
    case diagnostic.details do
      # for backwards compatibility with elixir < 1.16
      %kind{} = payload when kind == MismatchedDelimiterError ->
        [
          %{
            "location" => %{
              "uri" => uri,
              "range" => range({payload.line, payload.column - 1, payload.line, payload.column - 1 + String.length(to_string(payload.opening_delimiter))}, source_file)
            },
            "message" => "opening delimiter: #{payload.opening_delimiter}"
          },
          %{
            "location" => %{
              "uri" => uri,
              "range" => range({payload.end_line, payload.end_column - 1, payload.end_line, payload.end_column - 1 + String.length(to_string(payload.closing_delimiter))}, source_file)
            },
            "message" => "closing delimiter: #{payload.closing_delimiter}"
          }
        ]
      %kind{end_line: end_line, opening_delimiter: opening_delimiter} = payload when kind == TokenMissingError and not is_nil(opening_delimiter) ->
        message = String.split(payload.description, "hint: ") |> hd
        [
          %{
            "location" => %{
              "uri" => uri,
              "range" => range({payload.line, payload.column - 1, payload.line, payload.column - 1 + String.length(to_string(payload.opening_delimiter))}, source_file)
            },
            "message" => "opening delimiter: #{payload.opening_delimiter}"
          },
          %{
            "location" => %{
              "uri" => uri,
              "range" => range(end_line, source_file)
            },
            "message" => message
          }
        ] ++ get_related_information_description(payload.description, uri, source_file)
      %{description: description} ->
        get_related_information_description(description, uri, source_file)
      _ -> []
    end ++ get_related_information_message(diagnostic.message, uri, source_file)
  end

  # for details see
  # https://hexdocs.pm/mix/1.13.4/Mix.Task.Compiler.Diagnostic.html#t:position/0
  # https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/#diagnostic

  # position is a 1 based line number
  # 0 means unknown
  # we return a 0 length range at first non whitespace character in line
  defp range(line_start, source_file)
       when is_integer(line_start) and not is_nil(source_file) do
    # line is 1 based
    lines = SourceFile.lines(source_file)

    {line_start_lsp, char_start_lsp} =
      if line_start > 0 do
        case Enum.at(lines, line_start - 1) do
          nil ->
            # position is outside file range - this will return end of the file
            SourceFile.elixir_position_to_lsp(lines, {line_start, 1})

          line ->
            # find first non whitespace character in line
            start_idx = String.length(line) - String.length(String.trim_leading(line)) + 1
            {line_start - 1, SourceFile.elixir_character_to_lsp(line, start_idx)}
        end
      else
        # position unknown
        # return begin of the file
        {0, 0}
      end

    %{
      "start" => %{
        "line" => line_start_lsp,
        "character" => char_start_lsp
      },
      "end" => %{
        "line" => line_start_lsp,
        "character" => char_start_lsp
      }
    }
  end

  # position is a 1 based line number and 0 based character cursor (UTF8)
  # we return a 0 length range exactly at that location
  defp range({line_start, char_start}, source_file)
       when not is_nil(source_file) do
    # some diagnostics are broken
    line_start = line_start || 1
    char_start = char_start || 0
    lines = SourceFile.lines(source_file)
    # elixir_position_to_lsp will handle positions outside file range
    {line_start_lsp, char_start_lsp} =
      SourceFile.elixir_position_to_lsp(lines, {line_start, char_start + 1})

    %{
      "start" => %{
        "line" => line_start_lsp,
        "character" => char_start_lsp
      },
      "end" => %{
        "line" => line_start_lsp,
        "character" => char_start_lsp
      }
    }
  end

  # position is a range defined by 1 based line numbers and 0 based character cursors (UTF8)
  # we return exactly that range
  defp range({line_start, char_start, line_end, char_end}, source_file)
       when not is_nil(source_file) do
    # some diagnostics are broken
    line_start = line_start || 1
    char_start = char_start || 0

    line_end = line_end || 1
    char_end = char_end || 0

    lines = SourceFile.lines(source_file)
    # elixir_position_to_lsp will handle positions outside file range
    {line_start_lsp, char_start_lsp} =
      SourceFile.elixir_position_to_lsp(lines, {line_start, char_start + 1})

    {line_end_lsp, char_end_lsp} =
      SourceFile.elixir_position_to_lsp(lines, {line_end, char_end + 1})

    %{
      "start" => %{
        "line" => line_start_lsp,
        "character" => char_start_lsp
      },
      "end" => %{
        "line" => line_end_lsp,
        "character" => char_end_lsp
      }
    }
  end

  # source file is unknown
  # we discard any position information as it is meaningless
  # unfortunately LSP does not allow `null` range so we need to return something
  defp range(_, _) do
    # we don't care about utf16 positions here as we send 0
    %{"start" => %{"line" => 0, "character" => 0}, "end" => %{"line" => 0, "character" => 0}}
  end
end
