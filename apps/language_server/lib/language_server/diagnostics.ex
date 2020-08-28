defmodule ElixirLS.LanguageServer.Diagnostics do
  alias ElixirLS.LanguageServer.SourceFile

  def normalize(diagnostics, root_path) do
    for diagnostic <- diagnostics do
      {type, file, line, description, stacktrace} =
        extract_message_info(diagnostic.message, root_path)

      diagnostic
      |> update_message(type, description, stacktrace)
      |> maybe_update_file(file)
      |> maybe_update_position(line, stacktrace)
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
          |> Enum.map(&"  │ #{&1}")
          |> Enum.join("\n")
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

  defp maybe_update_position(diagnostic, line, stacktrace) do
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
    # since elixir 1.11 eex compiler returns line and column on error
    case Regex.run(~r/^(.*?):(\d+)(:(\d+))?: (.*)/s, message) do
      [_, file, line, description] -> {file, line, 0, description}
      [_, file, line, _, column, description] -> {file, line, column, description}
      _ -> nil
    end
  end

  defp file_path(file, root_path) do
    path = Path.join([root_path, file])

    if File.exists?(path) do
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
end
