defmodule ElixirLS.DebugAdapter.ExUnitFormatterTest do
  # Drives the real ExUnitFormatter GenServer with ExUnit events and asserts that
  # the corresponding `ex_unit` notifications are emitted through Output. Output's
  # group leader is swapped for a PacketCapture so emitted DAP packets arrive in
  # the test process (the same mechanism the debugger tests use).
  use ExUnit.Case, async: false

  alias ElixirLS.DebugAdapter.{ExUnitFormatter, Output}
  alias ElixirLS.Utils.PacketCapture

  @test_file "/abs/project/test/example_test.exs"

  setup do
    {:ok, packet_capture} = PacketCapture.start_link(self())
    output = Process.whereis(Output)
    default_group_leader = Process.info(output)[:group_leader]
    Process.group_leader(output, packet_capture)

    {:ok, formatter} = ExUnitFormatter.start_link([])

    on_exit(fn ->
      Process.group_leader(Process.whereis(Output), default_group_leader)
      if Process.alive?(formatter), do: GenServer.stop(formatter)
    end)

    {:ok, %{formatter: formatter}}
  end

  defp make_test(overrides) do
    tags = %{test_type: :test, describe: nil, file: @test_file, line: 7}

    %ExUnit.Test{
      name: :"test greets the world",
      module: ExampleTest,
      state: nil,
      time: 0,
      tags: Map.merge(tags, Map.get(overrides, :tags, %{}))
    }
    |> Map.merge(Map.delete(overrides, :tags))
  end

  defp send_event(formatter, message) do
    GenServer.cast(formatter, message)
  end

  test "emits test_started for a starting test", %{formatter: formatter} do
    send_event(formatter, {:test_started, make_test(%{state: nil})})

    assert_receive %{
      "event" => "output",
      "body" => %{"category" => "ex_unit", "data" => data}
    }

    assert data["event"] == "test_started"
    assert data["name"] == "greets the world"
    assert data["type"] == "test"
    assert data["module"] == "ExampleTest"
    assert data["file"] == @test_file
  end

  test "emits test_passed with timing", %{formatter: formatter} do
    send_event(formatter, {:test_finished, make_test(%{state: nil, time: 1234})})

    assert_receive %{"body" => %{"category" => "ex_unit", "data" => data}}
    assert data["event"] == "test_passed"
    assert data["name"] == "greets the world"
    assert data["time"] == 1234
  end

  test "emits test_failed with a formatted message", %{formatter: formatter} do
    failures =
      try do
        raise "boom"
      rescue
        e -> [{:error, e, __STACKTRACE__}]
      end

    send_event(formatter, {:test_finished, make_test(%{state: {:failed, failures}})})

    assert_receive %{"body" => %{"category" => "ex_unit", "data" => data}}
    assert data["event"] == "test_failed"
    assert data["name"] == "greets the world"
    assert is_binary(data["message"])
    assert data["message"] =~ "boom"
  end

  test "emits test_skipped for a skipped test", %{formatter: formatter} do
    send_event(formatter, {:test_started, make_test(%{state: {:skipped, "skip"}})})

    assert_receive %{"body" => %{"category" => "ex_unit", "data" => data}}
    assert data["event"] == "test_skipped"
  end

  test "emits test_excluded for an excluded test", %{formatter: formatter} do
    send_event(formatter, {:test_started, make_test(%{state: {:excluded, "exclude"}})})

    assert_receive %{"body" => %{"category" => "ex_unit", "data" => data}}
    assert data["event"] == "test_excluded"
  end

  test "emits test_errored for an invalid test (setup_all failure)", %{formatter: formatter} do
    failures =
      try do
        raise "setup boom"
      rescue
        e -> [{:error, e, __STACKTRACE__}]
      end

    test_module = %ExUnit.TestModule{
      name: ExampleTest,
      state: {:failed, failures},
      tests: []
    }

    send_event(formatter, {:test_finished, make_test(%{state: {:invalid, test_module}})})

    assert_receive %{"body" => %{"category" => "ex_unit", "data" => data}}
    assert data["event"] == "test_errored"
    assert is_binary(data["message"])
  end

  # `:cover` lives in the optional OTP `tools` app, which is not always on the
  # code path (e.g. a bare `mix test` run here). The coverage notification path is
  # only exercised under `mix test --cover`, where cover is loaded; run this test
  # when cover is available and mark it skipped otherwise rather than dropping it.
  @cover_available match?({:module, :cover}, Code.ensure_loaded(:cover))

  describe "coverage notifications" do
    @describetag skip: unless(@cover_available, do: "OTP :cover (tools app) not available")

    setup do
      cover_was_running = is_pid(Process.whereis(:cover_server))
      tmp = Path.join(System.tmp_dir!(), "els_cov_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      source = Path.join(tmp, "els_cov_fixture.ex")

      File.write!(source, """
      defmodule ElsCovFixture do
        def covered, do: :ok
        def uncovered, do: :never
      end
      """)

      {:ok, [module], _} = Kernel.ParallelCompiler.compile_to_path([source], tmp)

      unless cover_was_running, do: apply(:cover, :start, [])
      apply(:cover, :compile_beam, [module])
      # exercise one function so it has coverage while the other does not
      module.covered()

      on_exit(fn ->
        if cover_was_running do
          apply(:cover, :reset, [module])
        else
          apply(:cover, :stop, [])
        end

        :code.purge(module)
        :code.delete(module)
        File.rm_rf(tmp)
      end)

      :ok
    end

    test "emits test_coverage at suite_finished", %{formatter: formatter} do
      send_event(formatter, {:suite_finished, %{run: 0, async: 0}})

      assert_receive %{"body" => %{"category" => "ex_unit", "data" => data}}, 10_000
      assert data["event"] == "test_coverage"

      file =
        Enum.find(data["files"], fn f -> Path.basename(f["file"]) == "els_cov_fixture.ex" end)

      assert file, "expected coverage for the fixture module, got: #{inspect(data["files"])}"

      # line coverage: the `covered/0` body line ran, `uncovered/0` did not
      lines = Map.new(file["lines"], fn [line, count] -> {line, count} end)
      assert Enum.any?(lines, fn {_line, count} -> count > 0 end)
      assert Enum.any?(lines, fn {_line, count} -> count == 0 end)

      # declaration coverage: both functions reported, only `covered/0` executed
      names = Enum.map(file["functions"], & &1["name"]) |> Enum.sort()
      assert "covered/0" in names
      assert "uncovered/0" in names
    end
  end
end
