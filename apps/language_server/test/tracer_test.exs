defmodule ElixirLS.LanguageServer.TracerTest do
  use ExUnit.Case, async: false
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.LanguageServer.Test.FixtureHelpers

  setup context do
    File.rm_rf!(FixtureHelpers.get_path(".elixir_ls/calls.dets"))
    File.rm_rf!(FixtureHelpers.get_path(".elixir_ls/modules.dets"))
    {:ok, _pid} = Tracer.start_link([])

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

  describe "call trace" do
    setup context do
      Tracer.set_project_dir(FixtureHelpers.get_path(""))

      {:ok, context}
    end

    defp sorted_calls() do
      :ets.tab2list(:"#{Tracer}:calls") |> Enum.sort()
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
               {{CalledModule, :called, 1},
                %{
                  "calling_module.ex" => [
                    %{
                      callee: {CalledModule, :called, 1},
                      column: 2,
                      file: "calling_module.ex",
                      line: 12
                    }
                  ],
                  "other_calling_module.ex" => [
                    %{
                      callee: {CalledModule, :called, 1},
                      column: 3,
                      file: "other_calling_module.ex",
                      line: 13
                    }
                  ]
                }}
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
               {{CalledModule, :called, 1},
                %{
                  "calling_module.ex" => [
                    %{
                      callee: {CalledModule, :called, 1},
                      column: 3,
                      file: "calling_module.ex",
                      line: 13
                    },
                    %{
                      callee: {CalledModule, :called, 1},
                      column: 2,
                      file: "calling_module.ex",
                      line: 12
                    }
                  ]
                }}
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
               {{CalledModule, :called, 1},
                %{
                  "calling_module.ex" => [
                    %{
                      callee: {CalledModule, :called, 1},
                      column: 2,
                      file: "calling_module.ex",
                      line: 12
                    }
                  ]
                }},
               {{CalledModule, :other_called, 1},
                %{
                  "other_calling_module.ex" => [
                    %{
                      callee: {CalledModule, :other_called, 1},
                      column: 3,
                      file: "other_calling_module.ex",
                      line: 13
                    }
                  ]
                }}
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
               {{CalledModule, :called, 1},
                %{
                  "calling_module.ex" => [
                    %{
                      callee: {CalledModule, :called, 1},
                      column: 2,
                      file: "calling_module.ex",
                      line: 12
                    }
                  ]
                }}
             ] == sorted_calls()

      Tracer.delete_calls_by_file("calling_module.ex")

      assert [] == sorted_calls()
    end
  end
end
