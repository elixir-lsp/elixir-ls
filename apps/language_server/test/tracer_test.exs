defmodule ElixirLS.LanguageServer.TracerTest do
  use ExUnit.Case, async: false
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.LanguageServer.Test.FixtureHelpers

  setup context do
    {:ok, _pid} = start_supervised(Tracer)

    {:ok, context}
  end

  test "set project dir" do
    project_path = FixtureHelpers.get_path("")

    Tracer.notify_settings_stored(project_path)

    assert GenServer.call(Tracer, :get_project_dir) == project_path
  end

  test "set deps path" do
    project_path = FixtureHelpers.get_path("")
    deps_path = Path.join(project_path, "deps")

    Tracer.notify_deps_path(deps_path)

    assert GenServer.call(Tracer, :get_deps_path) == deps_path
  end

  describe "call trace" do
    setup context do
      project_path = FixtureHelpers.get_path("")
      Tracer.notify_settings_stored(project_path)
      Tracer.notify_deps_path(Path.join(project_path, "deps"))
      GenServer.call(Tracer, :get_project_dir)

      {:ok, context |> Map.put(:project_path, project_path)}
    end

    defp sorted_calls() do
      :ets.tab2list(:"#{Tracer}:calls") |> Enum.map(&(&1 |> elem(0))) |> Enum.sort()
    end

    test "trace is empty" do
      assert sorted_calls() == []
    end

    test "registers calls same function different files", %{project_path: project_path} do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: Path.join(project_path, "calling_module.ex")
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :called, 1},
        %Macro.Env{
          module: OtherCallingModule,
          file: Path.join(project_path, "other_calling_module.ex")
        }
      )

      assert [
               {{CalledModule, :called, 1}, Path.join(project_path, "calling_module.ex"), 12, 2},
               {{CalledModule, :called, 1}, Path.join(project_path, "other_calling_module.ex"),
                13, 3}
             ] == sorted_calls()
    end

    test "registers calls same function in one file", %{project_path: project_path} do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: Path.join(project_path, "calling_module.ex")
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: Path.join(project_path, "calling_module.ex")
        }
      )

      assert [
               {{CalledModule, :called, 1}, Path.join(project_path, "calling_module.ex"), 12, 2},
               {{CalledModule, :called, 1}, Path.join(project_path, "calling_module.ex"), 13, 3}
             ] == sorted_calls()
    end

    test "registers calls different functions", %{project_path: project_path} do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: Path.join(project_path, "calling_module.ex")
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :other_called, 1},
        %Macro.Env{
          module: OtherCallingModule,
          file: Path.join(project_path, "other_calling_module.ex")
        }
      )

      assert [
               {{CalledModule, :called, 1}, Path.join(project_path, "calling_module.ex"), 12, 2},
               {{CalledModule, :other_called, 1},
                Path.join(project_path, "other_calling_module.ex"), 13, 3}
             ] == sorted_calls()
    end

    test "deletes calls by file", %{project_path: project_path} do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: Path.join(project_path, "calling_module.ex")
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :called, 1},
        %Macro.Env{
          module: OtherCallingModule,
          file: Path.join(project_path, "other_calling_module.ex")
        }
      )

      Tracer.delete_calls_by_file(Path.join(project_path, "other_calling_module.ex"))

      assert [
               {{CalledModule, :called, 1}, Path.join(project_path, "calling_module.ex"), 12, 2}
             ] == sorted_calls()

      Tracer.delete_calls_by_file(Path.join(project_path, "calling_module.ex"))

      assert [] == sorted_calls()
    end
  end
end
