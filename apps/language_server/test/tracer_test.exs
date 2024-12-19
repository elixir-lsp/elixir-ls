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

  describe "call trace" do
    setup context do
      project_path = FixtureHelpers.get_path("")
      Tracer.notify_settings_stored(project_path)
      GenServer.call(Tracer, :get_project_dir)

      {:ok, context}
    end

    defp sorted_calls() do
      :ets.tab2list(:"#{Tracer}:calls") |> Enum.map(&(&1 |> elem(0))) |> Enum.sort()
    end

    test "trace is empty" do
      assert sorted_calls() == []
    end

    test "registers calls same function different files" do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: "calling_module.ex"
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :called, 1},
        %Macro.Env{
          module: OtherCallingModule,
          file: "other_calling_module.ex"
        }
      )

      assert [
               {{CalledModule, :called, 1}, "calling_module.ex", 12, 2},
               {{CalledModule, :called, 1}, "other_calling_module.ex", 13, 3}
             ] == sorted_calls()
    end

    test "registers calls same function in one file" do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: "calling_module.ex"
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: "calling_module.ex"
        }
      )

      assert [
               {{CalledModule, :called, 1}, "calling_module.ex", 12, 2},
               {{CalledModule, :called, 1}, "calling_module.ex", 13, 3}
             ] == sorted_calls()
    end

    test "registers calls different functions" do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: "calling_module.ex"
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :other_called, 1},
        %Macro.Env{
          module: OtherCallingModule,
          file: "other_calling_module.ex"
        }
      )

      assert [
               {{CalledModule, :called, 1}, "calling_module.ex", 12, 2},
               {{CalledModule, :other_called, 1}, "other_calling_module.ex", 13, 3}
             ] == sorted_calls()
    end

    test "deletes calls by file" do
      Tracer.trace(
        {:remote_function, [line: 12, column: 2], CalledModule, :called, 1},
        %Macro.Env{
          module: CallingModule,
          file: "calling_module.ex"
        }
      )

      Tracer.trace(
        {:remote_function, [line: 13, column: 3], CalledModule, :called, 1},
        %Macro.Env{
          module: OtherCallingModule,
          file: "other_calling_module.ex"
        }
      )

      Tracer.delete_calls_by_file("other_calling_module.ex")

      assert [
               {{CalledModule, :called, 1}, "calling_module.ex", 12, 2}
             ] == sorted_calls()

      Tracer.delete_calls_by_file("calling_module.ex")

      assert [] == sorted_calls()
    end
  end
end
