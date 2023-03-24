defmodule ElixirLS.LanguageServer.TracerTest do
  use ExUnit.Case, async: false
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.LanguageServer.Test.FixtureHelpers

  setup context do
    File.rm_rf!(FixtureHelpers.get_path(".elixir_ls/tracer_db.manifest"))
    File.rm_rf!(FixtureHelpers.get_path(".elixir_ls/calls.dets"))
    File.rm_rf!(FixtureHelpers.get_path(".elixir_ls/modules.dets"))
    {:ok, _pid} = start_supervised(Tracer)

    {:ok, context}
  end

  test "project dir is nil" do
    assert GenServer.call(Tracer, :get_project_dir) == nil
  end

  test "set project dir" do
    project_path = FixtureHelpers.get_path("")

    Tracer.set_project_dir(project_path)

    assert GenServer.call(Tracer, :get_project_dir) == project_path
  end

  test "saves DETS" do
    Tracer.set_project_dir(FixtureHelpers.get_path(""))

    Tracer.save()

    assert File.exists?(FixtureHelpers.get_path(".elixir_ls/calls.dets"))
    assert File.exists?(FixtureHelpers.get_path(".elixir_ls/modules.dets"))
  end

  test "skips save if project dir not set" do
    Tracer.save()
  end

  describe "call trace" do
    setup context do
      Tracer.set_project_dir(FixtureHelpers.get_path(""))

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

  describe "manifest" do
    test "return nil when not found" do
      project_path = FixtureHelpers.get_path("")
      assert nil == Tracer.read_manifest(project_path)
    end

    test "reads manifest" do
      project_path = FixtureHelpers.get_path("")
      Tracer.write_manifest(project_path)

      assert 3 == Tracer.read_manifest(project_path)
    end
  end
end
