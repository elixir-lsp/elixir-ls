defmodule ElixirLS.LanguageServer.Diagnostics do
  @moduledoc """
  This module provides utility functions for normalizing diagnostics
  from various sources
  """
  alias ElixirLS.LanguageServer.{SourceFile, JsonRpc}

  @enforce_keys [:file, :severity, :message, :position, :compiler_name]
  defstruct [
    :file,
    :severity,
    :message,
    :position,
    :compiler_name,
    span: nil,
    details: nil,
    stacktrace: []
  ]

  def from_mix_task_compiler_diagnostic(
        %Mix.Task.Compiler.Diagnostic{} = diagnostic,
        mixfile,
        root_path
      ) do
    diagnostic_fields = diagnostic |> Map.from_struct() |> Map.delete(:__struct__)
    normalized = struct(__MODULE__, diagnostic_fields)

    if Version.match?(System.version(), ">= 1.16.0-dev") do
      # don't include stacktrace in exceptions with position
      message =
        if diagnostic.file not in [nil, "nofile"] and diagnostic.position != 0 and
             is_tuple(diagnostic.details) and tuple_size(diagnostic.details) == 2 do
          {kind, reason} = diagnostic.details
          Exception.format_banner(kind, reason)
        else
          diagnostic.message
        end

      {file, position} =
        get_file_and_position_with_stacktrace_fallback(
          {diagnostic.file, diagnostic.position},
          Map.fetch!(diagnostic, :stacktrace),
          root_path,
          mixfile
        )

      %__MODULE__{normalized | message: message, file: file, position: position}
    else
      {type, file, position, stacktrace} =
        extract_message_info(diagnostic.message, root_path)

      normalized
      |> maybe_update_file(file, mixfile)
      |> maybe_update_position(type, position, stacktrace)
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
    # this regex won't match filenames with spaces
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

  def from_kernel_parallel_compiler_tuple({file, position, message}, severity, fallback_file) do
    %__MODULE__{
      compiler_name: "Elixir",
      file: file || fallback_file,
      position: position,
      message: message,
      severity: severity
    }
  end

  def from_code_diagnostic(
        %{
          file: file,
          severity: severity,
          message: message,
          position: position,
          stacktrace: stacktrace
        } = diagnostic,
        fallback_file,
        root_path
      ) do
    {file, position} =
      get_file_and_position_with_stacktrace_fallback(
        {file, position},
        stacktrace,
        root_path,
        fallback_file
      )

    %__MODULE__{
      compiler_name: "Elixir",
      file: file,
      position: position,
      # elixir >= 1.16
      span: diagnostic[:span],
      # elixir >= 1.16
      details: diagnostic[:details],
      stacktrace: stacktrace,
      message: message,
      severity: severity
    }
  end

  def from_error(kind, payload, stacktrace, file, project_dir) do
    # assume file is absolute
    {position, span} = get_line_span(file, payload, stacktrace, project_dir)

    message =
      if position do
        # NOTICE get_line_span returns nil position on failure
        # known and expected errors have defined position
        Exception.format_banner(kind, payload)
      else
        Exception.format(kind, payload, stacktrace)
      end

    # try to get position from first matching stacktrace for that file
    position = position || get_position_from_stacktrace(stacktrace, file, project_dir)

    %__MODULE__{
      compiler_name: "Elixir",
      stacktrace: stacktrace,
      file: file,
      position: position,
      span: span,
      message: message,
      severity: :error,
      details: {kind, payload}
    }
  end

  def from_shutdown_reason(error, fallback_file, root_path) when not is_nil(fallback_file) do
    msg = Exception.format_exit(error)

    {{file, position}, stacktrace} =
      case error do
        {_payload, [{_, _, _, info} | _] = stacktrace} when is_list(info) ->
          if candidate = get_file_position_from_stacktrace(stacktrace, root_path) do
            {candidate, stacktrace}
          else
            {{fallback_file, 0}, stacktrace}
          end

        _ ->
          {{fallback_file, 0}, []}
      end

    %__MODULE__{
      compiler_name: "Elixir",
      file: file,
      position: position,
      message: msg,
      severity: :error,
      stacktrace: stacktrace,
      details: {:exit, error}
    }
  end

  def publish_file_diagnostics(uri, uri_diagnostics, source_file, version) do
    diagnostics_json =
      for %__MODULE__{} = diagnostic <- uri_diagnostics do
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
          "range" => range(normalize_position(diagnostic), source_file),
          "source" => diagnostic.compiler_name,
          "relatedInformation" => build_related_information(diagnostic, uri, source_file),
          "tags" => get_tags(diagnostic)
        }
      end
      |> Enum.sort_by(& &1["range"]["start"])
      |> Enum.dedup()

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
    unused =
      if Regex.match?(~r/unused|no effect/u, diagnostic.message) do
        [1]
      else
        []
      end

    deprecated =
      if Regex.match?(~r/deprecated/u, diagnostic.message) do
        [2]
      else
        []
      end

    unused ++ deprecated
  end

  defp get_related_information_description(description, uri, source_file) do
    line =
      case Regex.run(
             ~r/line (\d+)/u,
             description
           ) do
        [_, line] -> String.to_integer(line)
        _ -> nil
      end

    message =
      case String.split(description, "hint: ") do
        [_, hint] ->
          hint

        _ ->
          case String.split(description, "HINT: ") do
            [_, hint] -> hint
            _ -> description
          end
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
    line =
      case Regex.run(
             ~r/line (\d+)/u,
             message
           ) do
        [_, line] ->
          String.to_integer(line)

        _ ->
          case Regex.run(
                 ~r/\.ex\:(\d+)\)/u,
                 message
               ) do
            [_, line] -> String.to_integer(line)
            _ -> nil
          end
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
      {:error, %kind{} = payload} when kind == MismatchedDelimiterError ->
        [
          %{
            "location" => %{
              "uri" => uri,
              "range" =>
                range(
                  {payload.line, payload.column, payload.line,
                   payload.column + String.length(to_string(payload.opening_delimiter))},
                  source_file
                )
            },
            "message" => "opening delimiter: #{payload.opening_delimiter}"
          },
          %{
            "location" => %{
              "uri" => uri,
              "range" =>
                range(
                  {payload.end_line, payload.end_column, payload.end_line,
                   payload.end_column + String.length(to_string(payload.closing_delimiter))},
                  source_file
                )
            },
            "message" => "closing delimiter: #{payload.closing_delimiter}"
          }
        ]

      {:error, %kind{opening_delimiter: opening_delimiter} = payload}
      when kind == TokenMissingError and not is_nil(opening_delimiter) ->
        [
          %{
            "location" => %{
              "uri" => uri,
              "range" =>
                range(
                  {payload.line, payload.column, payload.line,
                   payload.column + String.length(to_string(payload.opening_delimiter))},
                  source_file
                )
            },
            "message" => "opening delimiter: #{payload.opening_delimiter}"
          },
          %{
            "location" => %{
              "uri" => uri,
              "range" => range({payload.end_line, payload.end_column}, source_file)
            },
            "message" => "expected delimiter: #{payload.expected_delimiter}"
          }
        ]

      {:error, %{description: description}} ->
        get_related_information_description(description, uri, source_file) ++
          get_related_information_message(diagnostic.message, uri, source_file)

      _ ->
        # elixir < 1.16 and other errors on 1.16
        get_related_information_message(diagnostic.message, uri, source_file)
    end
  end

  defp normalize_position(%{
         position: {start_line, start_column},
         span: {end_line, end_column},
         details: %kind{closing_delimiter: closing_delimiter}
       })
       when kind == MismatchedDelimiterError do
    # convert to pre 1.16 4-tuple
    # include mismatched delimiter in range
    {start_line, start_column, end_line, end_column + String.length(to_string(closing_delimiter))}
  end

  defp normalize_position(%{position: {start_line, start_column}, span: {end_line, end_column}}) do
    # convert to pre 1.16 4-tuple
    {start_line, start_column, end_line, end_column}
  end

  defp normalize_position(%{position: position}), do: position

  # position is a 1 based line number or 0 if line is unknown
  # we return a 0 length range at first non whitespace character in line
  # or first position in file if line is unknown
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

  # position is a 1 based line number and 1 based character cursor (UTF8)
  # we return a 0 length range exactly at that location
  defp range({line_start, char_start}, source_file)
       when not is_nil(source_file) do
    # some diagnostics are broken
    line_start = max(line_start, 1)
    char_start = max(char_start, 1)
    lines = SourceFile.lines(source_file)
    # elixir_position_to_lsp will handle positions outside file range
    {line_start_lsp, char_start_lsp} =
      SourceFile.elixir_position_to_lsp(lines, {line_start, char_start})

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

  # position is a range defined by 1 based line numbers and 1 based character cursors (UTF8)
  # we return exactly that range
  defp range({line_start, char_start, line_end, char_end}, source_file)
       when not is_nil(source_file) do
    # some diagnostics are broken
    line_start = max(line_start, 1)
    char_start = max(char_start, 1)

    line_end = max(line_end, 1)
    char_end = max(char_end, 1)

    lines = SourceFile.lines(source_file)
    # elixir_position_to_lsp will handle positions outside file range
    {line_start_lsp, char_start_lsp} =
      SourceFile.elixir_position_to_lsp(lines, {line_start, char_start})

    {line_end_lsp, char_end_lsp} =
      SourceFile.elixir_position_to_lsp(lines, {line_end, char_end})

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

  # this utility function is copied from elixir source
  # TODO colum >= 0 PR
  def get_line_span(
        _file,
        %{line: line, column: column, end_line: end_line, end_column: end_column},
        _stack,
        _project_dir
      )
      when is_integer(line) and line > 0 and is_integer(column) and column > 0 and
             is_integer(end_line) and end_line > 0 and is_integer(end_column) and end_column > 0 do
    {{line, column}, {end_line, end_column}}
  end

  def get_line_span(_file, %{line: line, column: column}, _stack, _project_dir)
      when is_integer(line) and line > 0 and is_integer(column) and column > 0 do
    {{line, column}, nil}
  end

  def get_line_span(_file, %{line: line}, _stack, _project_dir)
      when is_integer(line) and line > 0 do
    {line, nil}
  end

  def get_line_span(file, :undef, [{_, _, _, []}, {_, _, _, info} | _], project_dir) do
    get_line_span_from_stacktrace_info(info, file, project_dir)
  end

  # we need that case as exception is normalized
  def get_line_span(
        file,
        %UndefinedFunctionError{},
        [{_, _, _, []}, {_, _, _, info} | _],
        project_dir
      ) do
    get_line_span_from_stacktrace_info(info, file, project_dir)
  end

  def get_line_span(
        file,
        _reason,
        [{_, _, _, [file: expanding]}, {_, _, _, info} | _],
        project_dir
      )
      when expanding in [~c"expanding macro", ~c"expanding struct"] do
    get_line_span_from_stacktrace_info(info, file, project_dir)
  end

  def get_line_span(file, _reason, [{_, _, _, info} | _], project_dir) do
    get_line_span_from_stacktrace_info(info, file, project_dir)
  end

  def get_line_span(_, _, _, _) do
    {nil, nil}
  end

  defp get_line_span_from_stacktrace_info(_info, _file, :no_stacktrace), do: {nil, nil}

  defp get_line_span_from_stacktrace_info(info, file, project_dir) do
    info_file = Keyword.get(info, :file)

    if info_file != nil and SourceFile.Path.absname(info_file, project_dir) == file do
      {Keyword.get(info, :line), nil}
    else
      {nil, nil}
    end
  end

  defp get_file_position_from_stacktrace(_stacktrace, :no_stacktrace), do: nil

  defp get_file_position_from_stacktrace(stacktrace, project_dir) do
    Enum.find_value(stacktrace, fn {_, _, _, info} ->
      if info_file = Keyword.get(info, :file) do
        info_file = SourceFile.Path.absname(info_file, project_dir)

        if SourceFile.Path.path_in_dir?(info_file, project_dir) and
             File.exists?(info_file, [:raw]) do
          {info_file, Keyword.get(info, :line, 0)}
        end
      end
    end)
  end

  defp get_position_from_stacktrace(_stacktrace, _file, :no_stacktrace), do: 0

  defp get_position_from_stacktrace(stacktrace, file, project_dir) do
    Enum.find_value(stacktrace, 0, fn {_, _, _, info} ->
      info_file = Keyword.get(info, :file)

      if info_file != nil and SourceFile.Path.absname(info_file, project_dir) == file do
        Keyword.get(info, :line)
      end
    end)
  end

  defp get_file_and_position_with_stacktrace_fallback(
         {nil, _},
         stacktrace,
         root_path,
         fallback_file
       ) do
    # file unknown, try to get first matching project file from stacktrace
    if candidate = get_file_position_from_stacktrace(stacktrace, root_path) do
      candidate
    else
      # we have to return something
      {fallback_file, 0}
    end
  end

  defp get_file_and_position_with_stacktrace_fallback(
         {file, 0},
         stacktrace,
         root_path,
         _fallback_file
       ) do
    # file known but position unknown - try first matching stacktrace entry from that file
    {file, get_position_from_stacktrace(stacktrace, file, root_path)}
  end

  defp get_file_and_position_with_stacktrace_fallback(
         {file, position},
         _stacktrace,
         _root_path,
         _fallback_file
       ) do
    {file, position}
  end
end
