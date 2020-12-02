defmodule ElixirLS.LanguageServer.Providers.CodeLens.Test do
  @moduledoc """
  Identifies test execution targets and provides code lenses for automatically executing them.

  Supports the following execution targets:
  * Test modules (any module that imports ExUnit.Case)
  * Describe blocks (any call to describe/2 inside a test module)
  * Test blocks (any call to test/2 or test/3 inside a test module)
  """

  alias ElixirLS.LanguageServer.Providers.CodeLens
  alias ElixirLS.LanguageServer.Providers.CodeLens.Test.DescribeBlock
  alias ElixirLS.LanguageServer.Providers.CodeLens.Test.TestBlock
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Metadata

  @run_test_command "elixir.lens.test.run"

  def code_lens(uri, text) do
    with {:ok, buffer_file_metadata} <- parse_source(text) do
      source_lines = SourceFile.lines(text)

      file_path = SourceFile.path_from_uri(uri)

      calls_list =
        buffer_file_metadata.calls
        |> Enum.map(fn {_k, v} -> v end)
        |> List.flatten()

      lines_to_env_list = Map.to_list(buffer_file_metadata.lines_to_env)

      describe_blocks = find_describe_blocks(lines_to_env_list, calls_list, source_lines)
      describe_lenses = get_describe_lenses(describe_blocks, file_path)

      test_lenses =
        lines_to_env_list
        |> find_test_blocks(calls_list, describe_blocks, source_lines)
        |> get_test_lenses(file_path)

      module_lenses =
        buffer_file_metadata
        |> get_test_modules()
        |> get_module_lenses(file_path)

      {:ok, test_lenses ++ describe_lenses ++ module_lenses}
    end
  end

  defp get_test_lenses(test_blocks, file_path) do
    args = fn block ->
      %{
        "filePath" => file_path,
        "testName" => block.name
      }
      |> Map.merge(if block.describe != nil, do: %{"describe" => block.describe.name}, else: %{})
    end

    test_blocks
    |> Enum.map(fn block ->
      CodeLens.build_code_lens(block.line, "Run test", @run_test_command, args.(block))
    end)
  end

  defp get_describe_lenses(describe_blocks, file_path) do
    describe_blocks
    |> Enum.map(fn block ->
      CodeLens.build_code_lens(block.line, "Run tests", @run_test_command, %{
        "filePath" => file_path,
        "describe" => block.name
      })
    end)
  end

  defp find_test_blocks(lines_to_env_list, calls_list, describe_blocks, source_lines) do
    runnable_functions = [{:test, 3}, {:test, 2}]

    for func <- runnable_functions,
        {line, _col} <- calls_to(calls_list, func),
        is_test_module?(lines_to_env_list, line) do
      {_line, %{scope_id: scope_id}} =
        Enum.find(lines_to_env_list, fn {env_line, _env} -> env_line == line end)

      describe =
        describe_blocks
        |> Enum.find(nil, fn describe ->
          describe.body_scope_id == scope_id
        end)

      %{"name" => test_name} =
        ~r/^\s*test "(?<name>.*)"(,.*)? do/
        |> Regex.named_captures(Enum.at(source_lines, line - 1))

      %TestBlock{name: test_name, describe: describe, line: line}
    end
  end

  defp find_describe_blocks(lines_to_env_list, calls_list, source_lines) do
    lines_to_env_list_length = length(lines_to_env_list)

    for {line, _col} <- calls_to(calls_list, {:describe, 2}),
        is_test_module?(lines_to_env_list, line) do
      DescribeBlock.find_block_info(
        line,
        lines_to_env_list,
        lines_to_env_list_length,
        source_lines
      )
    end
  end

  defp get_module_lenses(test_modules, file_path) do
    test_modules
    |> Enum.map(fn {module, line} ->
      CodeLens.build_code_lens(line, "Run tests in module", @run_test_command, %{
        "filePath" => file_path,
        "module" => module
      })
    end)
  end

  defp get_test_modules(%Metadata{lines_to_env: lines_to_env}) do
    lines_to_env
    |> Enum.group_by(fn {_line, env} -> env.module end)
    |> Enum.filter(fn {_module, module_lines_to_env} -> is_test_module?(module_lines_to_env) end)
    |> Enum.map(fn {module, [{line, _env} | _rest]} -> {module, line} end)
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
  end

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
