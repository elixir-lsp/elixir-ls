defmodule ElixirLS.DebugAdapter.ExUnitFormatter do
  use GenServer
  alias ElixirLS.DebugAdapter.CoverageData
  alias ElixirLS.DebugAdapter.Output

  @width 80

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.delete(args, :name),
      name: Keyword.get(args, :name, __MODULE__)
    )
  end

  @impl true
  def init(_args) do
    {:ok,
     %{
       failure_counter: 0
     }}
  end

  @impl true
  def terminate(reason, _state) do
    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        message = Exception.format_exit(reason)

        Output.telemetry(
          "dap_server_error",
          %{
            "elixir_ls.dap_process" => inspect(__MODULE__),
            "elixir_ls.dap_server_error" => message
          },
          %{}
        )

        Output.debugger_important("Terminating #{__MODULE__}: #{message}")
    end

    :ok
  end

  @impl true
  def handle_cast({:suite_started, _opts}, state) do
    # the suite has started with the specified options to the runner
    # we don't need to do anything
    {:noreply, state}
  end

  def handle_cast({:suite_finished, _times_us}, state) do
    # the suite has finished. Returns several measurements in microseconds for running the suite
    # if coverage was enabled (e.g. `mix test --cover`) report it back to the client
    report_coverage()
    {:noreply, state}
  end

  def handle_cast({:module_started, %ExUnit.TestModule{}}, state) do
    # a test module has started
    # we report on individual tests
    {:noreply, state}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{}}, state) do
    # a test module has finished
    # we report on individual tests
    {:noreply, state}
  end

  def handle_cast({:test_started, test = %ExUnit.Test{}}, state) do
    # a test has started
    case test.state do
      nil ->
        # initial state
        Output.ex_unit_event(%{
          "event" => "test_started",
          "type" => test.tags.test_type,
          "name" => test_name(test),
          "describe" => test.tags.describe,
          "module" => inspect(test.module),
          "file" => test.tags.file
        })

      {:skipped, _} ->
        # Skipped via @tag :skip
        Output.ex_unit_event(%{
          "event" => "test_skipped",
          "type" => test.tags.test_type,
          "name" => test_name(test),
          "describe" => test.tags.describe,
          "module" => inspect(test.module),
          "file" => test.tags.file
        })

      {:excluded, _} ->
        # Excluded via :exclude filters
        Output.ex_unit_event(%{
          "event" => "test_excluded",
          "type" => test.tags.test_type,
          "name" => test_name(test),
          "describe" => test.tags.describe,
          "module" => inspect(test.module),
          "file" => test.tags.file
        })

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_cast({:test_finished, test = %ExUnit.Test{}}, state) do
    # a test has finished
    state =
      case test.state do
        nil ->
          # Passed
          Output.ex_unit_event(%{
            "event" => "test_passed",
            "type" => test.tags.test_type,
            "time" => test.time,
            "name" => test_name(test),
            "describe" => test.tags.describe,
            "module" => inspect(test.module),
            "file" => test.tags.file
          })

          state

        {:excluded, _} ->
          # Excluded via :exclude filters
          state

        {:failed, failures} ->
          # Failed
          formatter_cb = fn _key, value -> value end

          message =
            ExUnit.Formatter.format_test_failure(
              test,
              failures,
              state.failure_counter + 1,
              @width,
              formatter_cb
            )

          Output.ex_unit_event(%{
            "event" => "test_failed",
            "type" => test.tags.test_type,
            "time" => test.time,
            "name" => test_name(test),
            "describe" => test.tags.describe,
            "module" => inspect(test.module),
            "file" => test.tags.file,
            "message" => message
          })

          %{state | failure_counter: state.failure_counter + 1}

        {:invalid, test_module = %ExUnit.TestModule{}} ->
          # Invalid (when setup_all fails)
          failures =
            case test_module.state do
              nil ->
                # workaround exunit bug
                # https://github.com/elixir-lang/elixir/issues/13373
                # TODO remove when we require elixir >= 1.17
                []

              {:failed, failures} ->
                failures
            end

          formatter_cb = fn _key, value -> value end

          message =
            try do
              ExUnit.Formatter.format_test_all_failure(
                test_module,
                failures,
                state.failure_counter + 1,
                @width,
                formatter_cb
              )
            rescue
              e ->
                Output.debugger_console(
                  "ExUnit.Formatter.format_test_all_failure failed: #{Exception.format(:error, e, __STACKTRACE__)}"
                )

                # Workaround for https://github.com/elixir-lang/elixir/issues/14900
                # TODO remove when we require elixir >= 1.20
                "invalid test module #{test_module}: #{inspect(failures)}"
            end

          Output.ex_unit_event(%{
            "event" => "test_errored",
            "type" => test.tags.test_type,
            "name" => test_name(test),
            "describe" => test.tags.describe,
            "module" => inspect(test.module),
            "file" => test.tags.file,
            "message" => message
          })

          %{state | failure_counter: state.failure_counter + 1}

        {:skipped, _} ->
          # Skipped via @tag :skip
          state
      end

    {:noreply, state}
  end

  def handle_cast({:sigquit, _tests}, state) do
    # the VM is going to shutdown. It receives the test cases (or test module in case of setup_all) still running
    # we probably don't need to do anything
    {:noreply, state}
  end

  def handle_cast(:max_failures_reached, state) do
    # the test run has been aborted due to reaching max failures limit set
    # with `:max_failures` option
    # we probably don't need to do anything
    {:noreply, state}
  end

  def handle_cast({:case_started, _test_case}, state) do
    # deprecated event, ignore
    # TODO remove when we require elixir 2.0
    {:noreply, state}
  end

  def handle_cast({:case_finished, _test_case}, state) do
    # deprecated event, ignore
    # TODO remove when we require elixir 2.0
    {:noreply, state}
  end

  # Coverage reporting
  #
  # When tests run with Mix's built-in coverage tool (`mix test --cover`), `:cover`
  # accumulates per-line call counts. At `suite_finished` (before Mix's own
  # after-suite callback stops/exports cover) we analyze that data and stream it
  # back to the client as a structured `test_coverage` event, grouped by source
  # file. The client maps it onto the editor's native test coverage UI.
  defp report_coverage() do
    if cover_running?() do
      try do
        files = collect_coverage()

        if files != [] do
          Output.ex_unit_event(%{
            "event" => "test_coverage",
            "files" => files
          })
        end
      rescue
        e ->
          Output.debugger_console(
            "ElixirLS: failed to collect test coverage: #{Exception.format(:error, e, __STACKTRACE__)}"
          )
      end
    end

    :ok
  end

  defp cover_running?() do
    is_pid(Process.whereis(:cover_server))
  end

  defp collect_coverage() do
    # Build per-module metadata (source file + function/clause line numbers from
    # the BEAM debug info), then layer three `:cover` analyses onto it:
    #   * lines     -> statement coverage   (`:line`)
    #   * functions -> declaration coverage (`:function`) — not exposed by Mix/ExUnit
    #   * clauses   -> branch coverage      (`:clause`)   — not exposed by Mix/ExUnit
    # The shaping/filtering is delegated to the (pure, unit-tested) CoverageData.
    meta = build_meta(cover_modules())

    CoverageData.build(
      analyse_rows(:line),
      analyse_rows(:function),
      analyse_rows(:clause),
      meta
    )
  end

  defp analyse_rows(level) do
    case safe_analyse(:calls, level) do
      {:result, ok, _fail} -> ok
      _ -> []
    end
  end

  # module => %{source: path, defs: %{{name, arity} => %{line, clause_lines}}}
  defp build_meta(modules) do
    for module <- modules, source = source_path(module), source != nil, into: %{} do
      {module, %{source: source, defs: module_defs(module)}}
    end
  end

  # Extracts the definition line and per-clause lines for every function in a
  # module from its BEAM debug info. Only Elixir modules (the `:elixir_erl`
  # backend) are supported; anything else yields %{} (line coverage still works).
  # Matching `:cover` rows against this map also filters out compiler-generated
  # functions such as `__info__/1`.
  defp module_defs(module) do
    with {:file, beam} <- safe_is_compiled(module),
         {:ok, {^module, [{:debug_info, {:debug_info_v1, :elixir_erl, {:elixir_v1, map, _}}}]}} <-
           :beam_lib.chunks(beam, [:debug_info]) do
      for {{name, arity}, _kind, fmeta, clauses} <- map.definitions,
          line = fmeta[:line],
          is_integer(line),
          into: %{} do
        clause_lines = for {cmeta, _args, _guards, _body} <- clauses, do: cmeta[:line]
        {{name, arity}, %{line: line, clause_lines: clause_lines}}
      end
    else
      _ -> %{}
    end
  rescue
    _ -> %{}
  catch
    _, _ -> %{}
  end

  defp cover_modules() do
    apply(:cover, :modules, [])
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  # `:cover` is part of the optional OTP `tools` app, loaded on demand when
  # coverage is enabled, so dispatch dynamically to avoid an xref warning.
  defp safe_analyse(analysis, level) do
    apply(:cover, :analyse, [analysis, level])
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  defp safe_is_compiled(module) do
    apply(:cover, :is_compiled, [module])
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  defp source_path(module) do
    case module.module_info(:compile)[:source] do
      nil ->
        nil

      source ->
        # source is the path as seen by the compiler (often relative to the
        # project dir, which is the cwd of the test run)
        path = source |> to_string() |> Path.expand()
        if File.exists?(path), do: path, else: nil
    end
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  # TODO extract to common module
  defp test_name(test = %ExUnit.Test{}) do
    describe = test.tags.describe
    # drop test prefix
    test_name = drop_test_prefix(test.name, test.tags.test_type)

    if describe != nil do
      test_name |> String.replace_prefix(describe <> " ", "")
    else
      test_name
    end
  end

  defp drop_test_prefix(test_name, kind),
    do: test_name |> Atom.to_string() |> String.replace_prefix(Atom.to_string(kind) <> " ", "")
end
