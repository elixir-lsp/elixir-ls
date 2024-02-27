defmodule ElixirLS.DebugAdapter.ExUnitFormatter do
  use GenServer
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
    # not interesting
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
            ExUnit.Formatter.format_test_all_failure(
              test_module,
              failures,
              state.failure_counter + 1,
              @width,
              formatter_cb
            )

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
    # undocumented event - we probably don't need to do anything
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
