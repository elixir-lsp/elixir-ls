defmodule ElixirLS.LanguageServer.Providers.CodeLens.Test do
  alias ElixirLS.LanguageServer.Providers.CodeLens
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Metadata

  @run_test_command "elixir.test.run"

  def code_lens(uri, text) do
    with {:ok, buffer_file_metadata} <- parse_source(text) do
      file_path = SourceFile.path_from_uri(uri)

      function_lenses = get_function_lenses(buffer_file_metadata, file_path)
      module_lenses = get_module_lenses(buffer_file_metadata, file_path)

      {:ok, function_lenses ++ module_lenses}
    end
  end

  defp get_module_lenses(%Metadata{} = metadata, file_path) do
    metadata
    |> get_test_modules()
    |> Enum.map(&build_test_module_code_lens(file_path, &1))
  end

  defp get_test_modules(%Metadata{lines_to_env: lines_to_env}) do
    lines_to_env
    |> Enum.group_by(fn {_line, env} -> env.module end)
    |> Enum.filter(fn {_module, module_lines_to_env} -> is_test_module?(module_lines_to_env) end)
    |> Enum.map(fn {module, [{line, _env} | _rest]} -> {module, line} end)
  end

  defp get_function_lenses(%Metadata{} = metadata, file_path) do
    runnable_functions = [{:test, 3}, {:test, 2}, {:describe, 2}]

    calls_list =
      metadata.calls
      |> Enum.map(fn {_k, v} -> v end)
      |> List.flatten()

    lines_to_env_list = Map.to_list(metadata.lines_to_env)

    for func <- runnable_functions,
        {line, _col} <- calls_to(calls_list, func),
        is_test_module?(lines_to_env_list, line) do
      build_function_test_code_lens(func, file_path, line)
    end
  end

  defp is_test_module?(lines_to_env), do: is_test_module?(lines_to_env, :infinity)

  defp is_test_module?(lines_to_env, line) when is_list(lines_to_env) do
    lines_to_env
    |> Enum.max_by(fn
      {env_line, _env} when env_line < line -> env_line
      _ -> -1
    end)
    |> elem(1)
    |> Map.get(:imports)
    |> Enum.any?(fn module -> module == ExUnit.Case end)
  end

  defp calls_to(calls_list, {function, arity}) do
    for call_info <- calls_list,
        call_info.func == function and call_info.arity === arity do
      call_info.position
    end

    # calls_list
    # |> Enum.filter(fn call_info -> call_info.func == function and call_info.arity === arity end)
    # |> Enum.map(fn call -> call.position end)
  end

  defp build_test_module_code_lens(file_path, {module, line}) do
    CodeLens.build_code_lens(line, "Run tests in module", @run_test_command, %{
      "file_path" => file_path,
      "module" => module
    })
  end

  defp build_function_test_code_lens(title, file_path, line) when is_binary(title) do
    CodeLens.build_code_lens(line, title, @run_test_command, %{
      "file_path" => file_path,
      "line" => line
    })
  end

  defp build_function_test_code_lens({:test, _arity}, file_path, line),
    do: build_function_test_code_lens("Run test", file_path, line)

  defp build_function_test_code_lens({:describe, _arity}, file_path, line),
    do: build_function_test_code_lens("Run tests", file_path, line)

  defp parse_source(text) do
    buffer_file_metadata =
      text
      |> Parser.parse_string(true, true, 1)

    if buffer_file_metadata.error != nil do
      {:error, buffer_file_metadata}
    else
      {:ok, buffer_file_metadata}
    end
  end
end
