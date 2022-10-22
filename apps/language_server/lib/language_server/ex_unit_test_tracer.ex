defmodule ElixirLS.LanguageServer.ExUnitTestTracer do
  use GenServer

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

  @impl true
  def handle_call({:get_tests, path}, _from, state) do
    :ets.delete_all_objects(table_name(:tests))
    tracers = Code.compiler_options()[:tracers]
    # TODO build lock?
    Code.put_compiler_option(:tracers, [__MODULE__])

    result =
      try do
        # TODO parallel compiler and diagnostics?
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
            tests
            |> Enum.map(fn %ExUnit.Test{tags: tags} = test ->
              # drop test prefix
              "test " <> test_name = Atom.to_string(test.name)

              test_name =
                if describe != nil do
                  test_name |> String.replace_prefix(describe <> " ", "")
                else
                  test_name
                end

              %{
                name: test_name,
                type: tags.test_type,
                line: tags.line - 1
              }
            end)

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
end
