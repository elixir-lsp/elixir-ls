defmodule ElixirLS.LanguageServer.ExUnitTestTracer do
  use GenServer
  alias ElixirLS.LanguageServer.Build
  alias ElixirLS.LanguageServer.JsonRpc
  require Logger

  @tables ~w(tests)a

  for table <- @tables do
    defp table_name(unquote(table)) do
      :"#{__MODULE__}:#{unquote(table)}"
    end
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get_tests(path) do
    GenServer.call(__MODULE__, {:get_tests, path}, :infinity)
  end

  @impl true
  def init(_args) do
    for table <- @tables do
      table_name = table_name(table)

      :ets.new(table_name, [
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    ExUnit.start(autorun: false)

    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, _state) do
    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        ElixirLS.LanguageServer.Server.do_sanity_check()
        message = Exception.format_exit(reason)

        JsonRpc.telemetry(
          "lsp_server_error",
          %{
            "elixir_ls.lsp_process" => inspect(__MODULE__),
            "elixir_ls.lsp_server_error" => message
          },
          %{}
        )

        Logger.info("Terminating #{__MODULE__}: #{message}")
    end

    :ok
  end

  @impl true
  def handle_call({:get_tests, path}, _from, state) do
    :ets.delete_all_objects(table_name(:tests))

    result =
      Build.with_build_lock(fn ->
        tracers = Code.compiler_options()[:tracers]

        Code.put_compiler_option(:tracers, [__MODULE__])

        try do
          # parallel compiler and diagnostics?
          _ = Code.compile_file(path)

          result =
            :ets.tab2list(table_name(:tests))
            |> Enum.map(fn {{_file, module, line}, describes} ->
              %{
                module: inspect(module),
                line: line,
                describes: describes
              }
            end)

          {:ok, result}
        rescue
          e ->
            {:error, e}
        after
          Code.put_compiler_option(:tracers, tracers)
        end
      end)

    {:reply, result, state}
  end

  def trace({:on_module, _, _}, %Macro.Env{} = env) do
    test_info = Module.get_attribute(env.module, :ex_unit_tests)

    if test_info != nil do
      describe_infos =
        test_info
        |> Enum.group_by(fn %ExUnit.Test{tags: tags} -> {tags.describe, tags.describe_line} end)
        |> Enum.map(fn {{describe, describe_line}, tests} ->
          tests =
            for %ExUnit.Test{tags: tags} = test <- tests do
              # drop test prefix
              test_name = drop_test_prefix(test.name, tags.test_type)

              test_name =
                if describe != nil do
                  test_name |> String.replace_prefix(describe <> " ", "")
                else
                  test_name
                end

              selected_tags =
                for {tag, value} <- tags, tag in [:async, :test_type, :doctest, :doctest_line] do
                  "#{tag}:#{format_tag(tag, value)}"
                end

              doctest_module_path =
                case tags[:doctest] do
                  nil ->
                    nil

                  module ->
                    if Code.ensure_loaded?(module) do
                      to_string(module.module_info(:compile)[:source])
                    end
                end

              %{
                name: test_name,
                type: tags.test_type,
                line: tags.line - 1,
                doctest_module_path: doctest_module_path,
                tags: selected_tags
              }
            end

          %{
            describe: describe,
            line: if(describe_line, do: describe_line - 1),
            tests: tests
          }
        end)

      :ets.insert(table_name(:tests), {{env.file, env.module, env.line - 1}, describe_infos})
    end

    :ok
  end

  def trace(_, %Macro.Env{} = _env) do
    :ok
  end

  defp drop_test_prefix(test_name, kind),
    do: test_name |> Atom.to_string() |> String.replace_prefix(Atom.to_string(kind) <> " ", "")

  defp format_tag(tag, value) when tag in [:doctest, :module] do
    inspect(value)
  end

  defp format_tag(:doctest_line, value) do
    to_string(value - 1)
  end

  defp format_tag(_tag, value) do
    to_string(value)
  end
end
