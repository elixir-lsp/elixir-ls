defmodule ElixirLS.DebugAdapter.ServerTest do
  # Awkwardly, testing that the debug adapter can debug ExUnit tests in the fixture project
  # gives us no way to capture the output, since ExUnit doesn't really distinguish
  # between the debug adapter tests and the fixture project's tests. Expect to see output printed
  # from both.

  alias ElixirLS.DebugAdapter.{Server, Protocol, BreakpointCondition, ModuleInfoCache, Output}
  use ElixirLS.Utils.MixTest.Case, async: false
  use Protocol

  doctest Server

  setup do
    {:ok, packet_capture} = ElixirLS.Utils.PacketCapture.start_link(self())
    default_group_leader = Process.info(Process.whereis(Output))[:group_leader]
    Process.group_leader(Process.whereis(Output), packet_capture)

    {:ok, _} = start_supervised(BreakpointCondition)
    {:ok, _} = start_supervised({ModuleInfoCache, %{}})
    {:ok, server} = Server.start_link(name: Server)

    on_exit(fn ->
      Process.group_leader(Process.whereis(Output), default_group_leader)
      for mod <- :int.interpreted(), do: :int.nn(mod)
      :int.auto_attach(false)
      :int.no_break()
      :int.clear()

      if Process.alive?(server) do
        Process.monitor(server)
        GenServer.stop(server)

        receive do
          {:DOWN, _, _, ^server, _} ->
            :ok
        end
      end
    end)

    {:ok, %{server: server}}
  end

  defp initialize_req_args() do
    %GenDAP.Structures.InitializeRequestArguments{client_i_d: "some_client_id", client_name: "My client", adapter_i_d: "some_id", locale: "", lines_start_at1: true, columns_start_at1: true, path_format: "path", supports_variable_type: false, supports_variable_paging: false, supports_run_in_terminal_request: false, supports_memory_references: false, supports_progress_reporting: false, supports_invalidated_event: false, supports_memory_event: false, supports_args_can_be_interpreted_by_shell: false, supports_start_debugging_request: false, supports_a_n_s_i_styling: false}
  end

  defp initialize_req_(seq, arguments \\ initialize_req_args()) do
    {:ok, rex} = Schematic.dump(GenDAP.Requests.Initialize.schematic(), %GenDAP.Requests.Initialize{seq: seq, arguments: arguments})
    rex
  end

  describe "initialize" do
    test "succeeds", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        assert %{"clientID" => "some_client_id"} = :sys.get_state(server).client_info
      end)
    end

    test "fails when already initialized", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(server, initialize_req_(2))

        assert_receive(
          error_response(
            _,
            2,
            "initialize",
            "invalidRequest",
            "Debugger request initialize was not expected",
            _,
            _,
            _
          )
        )
      end)
    end

    test "fails when not supported arguments passed", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(
          server,
          initialize_req_(1, %{initialize_req_args() | lines_start_at1: false})
        )

        assert_receive(
          error_response(
            _,
            1,
            "initialize",
            "invalidRequest",
            "0-based lines are not supported",
            %{},
            _,
            _
          )
        )
      end)
    end

    test "rejects requests when not initialized", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(
          server,
          set_breakpoints_req(1, %{"path" => Path.absname("lib/mix_project.ex")}, [%{"line" => 3}])
        )

        assert_receive(
          error_response(
            _,
            1,
            "setBreakpoints",
            "invalidRequest",
            "Debugger request setBreakpoints was not expected",
            _,
            _,
            _
          )
        )
      end)
    end
  end

  describe "disconnect" do
    test "succeeds when not initialized", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Process.flag(:trap_exit, true)
        Server.receive_packet(server, request(1, "disconnect") |> IO.inspect)
        assert_receive(response(_, 1, "disconnect", %{}))
        assert_receive({:EXIT, ^server, {:exit_code, 0}})
      end)
    after
      Process.flag(:trap_exit, false)
    end

    test "succeeds when initialized", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Process.flag(:trap_exit, true)
        Server.receive_packet(server, initialize_req_(1))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(server, request(2, "disconnect"))
        assert_receive(response(_, 2, "disconnect", %{}))
        assert_receive({:EXIT, ^server, {:exit_code, 0}})
      end)
    after
      Process.flag(:trap_exit, false)
    end
  end

  @tag :fixture
  test "basic debugging", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["-e", "Some.fun_1(2)"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))
      abs_path = Path.absname("lib/mix_project.ex")

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 50}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
        5000
      )

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}))
      # ensure thread ids are unique
      thread_ids = Enum.map(threads, & &1["id"])
      assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id
                     }),
                     5_000

      Server.receive_packet(server, stacktrace_req(7, thread_id))

      assert_receive response(_, 7, "stackTrace", %{
                       "totalFrames" => 1,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "id" => frame_id,
                           "line" => 50,
                           "name" => "Some.fun_1/1",
                           "source" => %{"path" => ^abs_path}
                         }
                       ]
                     })
                     when is_integer(frame_id)

      Server.receive_packet(server, scopes_req(8, frame_id))

      assert_receive response(_, 8, "scopes", %{
                       "scopes" => [
                         %{
                           "expensive" => false,
                           "indexedVariables" => 0,
                           "name" => "variables",
                           "namedVariables" => 1,
                           "variablesReference" => vars_id
                         },
                         %{
                           "expensive" => false,
                           "indexedVariables" => 0,
                           "name" => "versioned variables",
                           "namedVariables" => 1,
                           "variablesReference" => _vars_id
                         },
                         %{
                           "expensive" => false,
                           "indexedVariables" => 0,
                           "name" => "process info",
                           "namedVariables" => _,
                           "variablesReference" => _
                         },
                         %{
                           "expensive" => false,
                           "indexedVariables" => 1,
                           "name" => "arguments",
                           "namedVariables" => 0,
                           "variablesReference" => _
                         }
                       ]
                     })

      Server.receive_packet(server, vars_req(9, vars_id))

      assert_receive response(_, 9, "variables", %{
                       "variables" => [
                         %{
                           "name" => "x",
                           "type" => "integer",
                           "value" => "2",
                           "variablesReference" => 0
                         }
                       ]
                     }),
                     1000

      Server.receive_packet(server, next_req(10, thread_id))
      assert_receive response(_, 10, "next", %{})

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "step",
                       "threadId" => ^thread_id
                     }),
                     5_000

      Server.receive_packet(server, stacktrace_req(11, thread_id))

      assert_receive response(_, 11, "stackTrace", %{
                       "totalFrames" => 1,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "line" => 51,
                           "name" => "Some.fun_1/1"
                         }
                       ]
                     })

      Server.receive_packet(server, step_in_req(12, thread_id))
      assert_receive response(_, 12, "stepIn", %{})

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "step",
                       "threadId" => ^thread_id
                     }),
                     5_000

      Server.receive_packet(server, stacktrace_req(13, thread_id))

      assert_receive response(_, 13, "stackTrace", %{
                       "totalFrames" => 2,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "line" => 56,
                           "name" => "Some.fun_2/1"
                         },
                         _
                       ]
                     })

      Server.receive_packet(server, step_out_req(14, thread_id))
      assert_receive response(_, 14, "stepOut", %{})

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "step",
                       "threadId" => ^thread_id
                     }),
                     5_000

      Server.receive_packet(server, stacktrace_req(11, thread_id))

      assert_receive response(_, 11, "stackTrace", %{
                       "totalFrames" => 1,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "line" => 52,
                           "name" => "Some.fun_1/1"
                         }
                       ]
                     })

      Server.receive_packet(server, continue_req(15, thread_id))
      assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

      assert_receive(
        event(_, "exited", %{
          "exitCode" => 0
        })
      )

      assert_receive(event(_, "terminated", %{"restart" => false}))
    end)
  end

  @tag :fixture
  test "no mix exs", %{server: server} do
    in_fixture(__DIR__, "no_mix_exs", fn ->
      Server.receive_packet(
        server,
        initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["--no-mix-exs", "script.exs"],
          "projectDir" => File.cwd!(),
          "exitAfterTaskReturns" => false,
          "requireFiles" => [
            "script.exs"
          ]
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))
      abs_path = Path.absname("script.exs")

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 4}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
        5000
      )

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}))
      # ensure thread ids are unique
      thread_ids = Enum.map(threads, & &1["id"])
      assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id
                     }),
                     5_000

      Server.receive_packet(server, stacktrace_req(7, thread_id))

      assert_receive response(_, 7, "stackTrace", %{
                       "totalFrames" => 1,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "id" => frame_id,
                           "line" => 4,
                           "name" => "Abc.debug_me/0",
                           "source" => %{"path" => ^abs_path}
                         }
                       ]
                     })
                     when is_integer(frame_id)

      Server.receive_packet(server, scopes_req(8, frame_id))

      assert_receive response(_, 8, "scopes", %{
                       "scopes" => [
                         %{
                           "expensive" => false,
                           "indexedVariables" => 0,
                           "name" => "variables",
                           "namedVariables" => 1,
                           "variablesReference" => vars_id
                         },
                         %{
                           "expensive" => false,
                           "indexedVariables" => 0,
                           "name" => "versioned variables",
                           "namedVariables" => 1,
                           "variablesReference" => _vars_id
                         },
                         %{
                           "expensive" => false,
                           "indexedVariables" => 0,
                           "name" => "process info",
                           "namedVariables" => _,
                           "variablesReference" => _
                         }
                       ]
                     })

      Server.receive_packet(server, vars_req(9, vars_id))

      assert_receive response(_, 9, "variables", %{
                       "variables" => [
                         %{
                           "name" => "a",
                           "type" => "list",
                           "value" => "[1, 2, 3]",
                           "variablesReference" => _
                         }
                       ]
                     }),
                     1000

      Server.receive_packet(server, continue_req(15, thread_id))
      assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})
    end)
  end

  @tag :fixture
  test "launch with no debug", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "noDebug" => true,
          "task" => "run",
          "taskArgs" => ["-e", "Some.fun_1(2)"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}))
      # ensure thread ids are unique
      thread_ids = Enum.map(threads, & &1["id"])
      assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

      assert_receive(
        event(_, "exited", %{
          "exitCode" => 0
        }),
        3000
      )

      assert_receive(event(_, "terminated", %{"restart" => false}))
    end)
  end

  @tag :fixture
  test "launch mix task that raises", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "noDebug" => true,
          "task" => "run",
          "taskArgs" => ["-e", "MixProject.Crash.fun_that_raises()"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      assert_receive event(_, "output", %{
                       "category" => "console",
                       "output" =>
                         "Mix task exited with reason\nan exception was raised:\n    ** (RuntimeError) foo" <>
                           _
                     }),
                     3000

      assert_receive(
        event(_, "exited", %{
          "exitCode" => 1
        }),
        3000
      )

      assert_receive(event(_, "terminated", %{"restart" => false}))
    end)
  end

  @tag :fixture
  test "launch mix task that fails to initialize", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "noDebug" => true,
          "task" => "ru/n",
          "taskArgs" => [],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(
        error_response(
          _,
          2,
          "launch",
          "launchError",
          "** (Mix.NoTaskError) The task \"ru/n\" could not be found" <> _,
          %{},
          _,
          _
        ),
        5000
      )

      refute_receive(event(_, "initialized", _))

      assert_receive(
        event(_, "exited", %{
          "exitCode" => 1
        }),
        3000
      )

      assert_receive(event(_, "terminated", %{"restart" => false}))
    end)
  end

  @tag :fixture
  test "launch invalid mix task", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "noDebug" => true,
          "task" => "nonexisting",
          "taskArgs" => [],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      assert_receive event(_, "output", %{
                       "category" => "console",
                       "output" =>
                         "Mix task exited with reason\nan exception was raised:\n    ** (Mix.NoTaskError) The task \"nonexisting\" could not be found" <>
                           _
                     }),
                     3000

      assert_receive(
        event(_, "exited", %{
          "exitCode" => 1
        }),
        3000
      )

      assert_receive(event(_, "terminated", %{"restart" => false}))
    end)
  end

  @tag :fixture
  test "multiple paused processes", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["-e", "Some.multiple(2)"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))
      abs_path = Path.absname("lib/mix_project.ex")

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 67}, %{"line" => 70}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{
          "breakpoints" => [%{"verified" => true}, %{"verified" => true}]
        }),
        5000
      )

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id_1
                     }),
                     5_000

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id_2
                     }),
                     5_000

      Server.receive_packet(server, stacktrace_req(7, thread_id_1))
      Server.receive_packet(server, stacktrace_req(8, thread_id_2))

      assert_receive response(_, 7, "stackTrace", %{
                       "totalFrames" => 1,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "id" => _frame_id,
                           "line" => line_1,
                           "source" => %{"path" => ^abs_path}
                         }
                       ]
                     })

      assert_receive response(_, 8, "stackTrace", %{
                       "totalFrames" => 1,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "id" => _frame_id,
                           "line" => line_2,
                           "source" => %{"path" => ^abs_path}
                         }
                       ]
                     })

      assert Enum.sort([line_1, line_2]) == [67, 70]

      Server.receive_packet(server, continue_req(9, thread_id_1))
      Server.receive_packet(server, continue_req(10, thread_id_2))
      assert_receive response(_, 9, "continue", %{"allThreadsContinued" => false})
      assert_receive response(_, 10, "continue", %{"allThreadsContinued" => true})
    end)
  end

  @tag :fixture
  test "handles invalid requests", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["-e", "MixProject.quadruple(1)"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => Path.absname("lib/mix_project.ex")}, [%{"line" => 3}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
        5000
      )

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}))
      # ensure thread ids are unique
      thread_ids = Enum.map(threads, & &1["id"])
      assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id
                     }),
                     5_000

      Server.receive_packet(server, stacktrace_req(7, -6543))

      assert_receive error_response(
                       _,
                       7,
                       "stackTrace",
                       "invalidArgument",
                       "Unable to find process pid for DAP threadId {threadId}",
                       %{"threadId" => "-6543"},
                       _,
                       _
                     )

      Server.receive_packet(server, scopes_req(8, -5345))

      assert_receive error_response(
                       _,
                       8,
                       "scopes",
                       "invalidArgument",
                       "frameId not found: {frameId}",
                       %{"frameId" => "-5345"},
                       _,
                       _
                     )

      Server.receive_packet(server, vars_req(9, -5345))

      assert_receive error_response(
                       _,
                       9,
                       "variables",
                       "invalidArgument",
                       "variablesReference not found: {variablesReference}",
                       %{"variablesReference" => "-5345"},
                       _,
                       _
                     )

      Server.receive_packet(server, next_req(10, -5345))

      assert_receive error_response(
                       _,
                       10,
                       "next",
                       "invalidArgument",
                       "Unable to find process pid for DAP threadId {threadId}",
                       %{"threadId" => "-5345"},
                       _,
                       _
                     )

      Server.receive_packet(server, step_in_req(11, -5345))

      assert_receive error_response(
                       _,
                       11,
                       "stepIn",
                       "invalidArgument",
                       "Unable to find process pid for DAP threadId {threadId}",
                       %{"threadId" => "-5345"},
                       _,
                       _
                     )

      Server.receive_packet(server, step_out_req(12, -5345))

      assert_receive error_response(
                       _,
                       12,
                       "stepOut",
                       "invalidArgument",
                       "Unable to find process pid for DAP threadId {threadId}",
                       %{"threadId" => "-5345"},
                       _,
                       _
                     )

      Server.receive_packet(server, continue_req(13, -5345))

      assert_receive error_response(
                       _,
                       13,
                       "continue",
                       "invalidArgument",
                       "Unable to find process pid for DAP threadId {threadId}",
                       %{"threadId" => "-5345"},
                       _,
                       _
                     )

      Server.receive_packet(server, request(14, "someRequest", %{"threadId" => 123}))

      assert_receive error_response(
                       _,
                       14,
                       "someRequest",
                       "notSupported",
                       "Debugger request someRequest is currently not supported",
                       _,
                       _,
                       _
                     )

      Server.receive_packet(server, continue_req(15, thread_id))
      assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

      Server.receive_packet(server, stacktrace_req(7, thread_id))
      thread_id_str = inspect(thread_id)

      assert_receive error_response(
                       _,
                       7,
                       "stackTrace",
                       "invalidArgument",
                       "Process with threadId {threadId} and pid {pid} is not paused",
                       %{"threadId" => ^thread_id_str, "pid" => _},
                       _,
                       _
                     )
    end)
  end

  @tag :fixture
  test "notifies about process exit", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["-e", "MixProject.exit()"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => Path.absname("lib/mix_project.ex")}, [%{"line" => 17}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
        5000
      )

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)
      # ensure thread ids are unique
      thread_ids = Enum.map(threads, & &1["id"])
      assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id
                     }),
                     5000

      {log, _stderr} =
        capture_log_and_io(:standard_error, fn ->
          assert_receive event(_, "thread", %{
                           "reason" => "exited",
                           "threadId" => ^thread_id
                         }),
                         5000
        end)

      assert log =~ "Fixture MixProject expected error"
    end)
  end

  @tag :fixture
  test "notifies about mix task exit", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["-e", "MixProject.exit_self()"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => Path.absname("lib/mix_project.ex")}, [%{"line" => 29}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
        5000
      )

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}))
      # ensure thread ids are unique
      thread_ids = Enum.map(threads, & &1["id"])
      assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id
                     }),
                     5000

      {log, _io} =
        capture_log_and_io(:stderr, fn ->
          assert_receive event(_, "thread", %{
                           "reason" => "exited",
                           "threadId" => ^thread_id
                         }),
                         5000
        end)

      assert log =~ "Fixture MixProject raise for exit_self/0"

      assert_receive event(_, "exited", %{
                       "exitCode" => 1
                     })

      assert_receive event(_, "terminated", %{
                       "restart" => false
                     })
    end)
  end

  @tag :fixture
  test "terminate threads", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["-e", "MixProject.Some.sleep()"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))
      Process.sleep(1000)
      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)

      assert [thread_id] =
               threads
               |> Enum.filter(&(&1["name"] |> String.starts_with?("MixProject.Some")))
               |> Enum.map(& &1["id"])

      Server.receive_packet(server, request(7, "terminateThreads", %{"threadIds" => [thread_id]}))
      assert_receive(response(_, 7, "terminateThreads", %{}), 500)

      assert_receive event(_, "thread", %{
                       "reason" => "exited",
                       "threadId" => ^thread_id
                     }),
                     5000
    end)
  end

  describe "pause" do
    @tag :fixture
    test "alive", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "MixProject.Some.sleep()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))
        Process.sleep(1000)
        Server.receive_packet(server, request(6, "threads", %{}))
        assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)

        assert [thread_id] =
                 threads
                 |> Enum.filter(&(&1["name"] |> String.starts_with?("MixProject.Some")))
                 |> Enum.map(& &1["id"])

        Server.receive_packet(server, request(7, "pause", %{"threadId" => thread_id}))
        assert_receive(response(_, 7, "pause", %{}), 500)

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "pause",
                         "threadId" => ^thread_id
                       }),
                       500

        assert_receive event(_, "output", %{
                         "category" => "console",
                         "output" => "Failed to obtain meta for pid" <> _
                       })
      end)
    end

    @tag :fixture
    test "dead", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "MixProject.Some.sleep()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))
        Process.sleep(1000)
        Server.receive_packet(server, request(6, "threads", %{}))
        assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)

        assert [thread_id] =
                 threads
                 |> Enum.filter(&(&1["name"] |> String.starts_with?("MixProject.Some")))
                 |> Enum.map(& &1["id"])

        Process.whereis(MixProject.Some) |> Process.exit(:kill)
        Process.sleep(1000)

        Server.receive_packet(server, request(7, "pause", %{"threadId" => thread_id}))
        assert_receive(response(_, 7, "pause", %{}), 500)

        assert_receive event(_, "thread", %{
                         "reason" => "exited",
                         "threadId" => ^thread_id
                       }),
                       5000
      end)
    end
  end

  describe "breakpoints" do
    @tag :fixture
    test "sets and unsets breakpoints in erlang modules", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute :hello in :int.interpreted()
        abs_path = Path.absname("src/hello.erl")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 5}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        Process.sleep(100)

        assert :hello in :int.interpreted()
        assert [{{:hello, 5}, [:active, :enable, :null, _]}] = :int.all_breaks(:hello)
        assert %{^abs_path => [{[:hello], 5}]} = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 5}, %{"line" => 6}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{
            "breakpoints" => [%{"verified" => true}, %{"verified" => true}]
          }),
          5000
        )

        assert [{{:hello, 5}, _}, {{:hello, 6}, _}] = :int.all_breaks(:hello)

        assert %{^abs_path => [{[:hello], 5}, {[:hello], 6}]} = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 6}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert [{{:hello, 6}, _}] = :int.all_breaks(:hello)
        assert %{^abs_path => [{[:hello], 6}]} = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end

    @tag :fixture
    test "handles invalid request", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute :hello in :int.interpreted()
        abs_path = Path.absname("src/hello.erl1")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 5}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => false}]}),
          5000
        )

        abs_path = Path.absname("lib/mix_project.ex1")

        Server.receive_packet(
          server,
          set_breakpoints_req(4, %{"path" => abs_path}, [%{"line" => 3}])
        )

        assert_receive(
          response(_, 4, "setBreakpoints", %{"breakpoints" => [%{"verified" => false}]}),
          5000
        )
      end)
    end

    @tag :fixture
    test "sets and unsets breakpoints in elixir modules", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute MixProject in :int.interpreted()
        refute MixProject.Some in :int.interpreted()
        abs_path = Path.absname("lib/mix_project.ex")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 3}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert MixProject in :int.interpreted()
        refute MixProject.Some in :int.interpreted()

        assert [{{MixProject, 3}, [:active, :enable, :null, _]}] = :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3},
            %{"line" => 7},
            %{"line" => 35}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{
            "breakpoints" => [%{"verified" => true}, %{"verified" => true}, %{"verified" => true}]
          }),
          5000
        )

        assert MixProject.Some in :int.interpreted()
        assert [{{MixProject, 3}, _}, {{MixProject, 7}, _}] = :int.all_breaks(MixProject)
        assert [{{MixProject.Some, 35}, _}] = :int.all_breaks(MixProject.Some)

        assert %{
                 ^abs_path => [{[MixProject], 3}, {[MixProject], 7}, {[MixProject.Some], 35}]
               } = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 35},
            %{"line" => 39}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{
            "breakpoints" => [%{"verified" => true}, %{"verified" => true}]
          }),
          5000
        )

        assert [] = :int.all_breaks(MixProject)

        assert [{{MixProject.Some, 35}, _}, {{MixProject.Some, 39}, _}] =
                 :int.all_breaks(MixProject.Some)

        assert %{^abs_path => [{[MixProject.Some], 35}, {[MixProject.Some], 39}]} =
                 :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] = :int.all_breaks(MixProject.Some)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end

    @tag :fixture
    test "sets and unsets breakpoints in different files", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute MixProject in :int.interpreted()
        refute :hello in :int.interpreted()

        abs_path_1 = Path.absname("lib/mix_project.ex")
        abs_path_2 = Path.absname("src/hello.erl")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path_1}, [%{"line" => 3}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert MixProject in :int.interpreted()
        refute :hello in :int.interpreted()

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] ==
                 :int.all_breaks(MixProject)

        assert %{^abs_path_1 => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path_2}, [%{"line" => 5}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        Process.sleep(100)

        assert :hello in :int.interpreted()
        assert [{{:hello, 5}, _}] = :int.all_breaks(:hello)

        assert %{abs_path_1 => [{[MixProject], 3}], abs_path_2 => [{[:hello], 5}]} ==
                 :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path_1}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] = :int.all_breaks(MixProject)
        assert [{{:hello, 5}, _}] = :int.all_breaks(:hello)
        assert %{abs_path_2 => [{[:hello], 5}]} == :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path_2}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end

    @tag :fixture
    test "sets, modifies and unsets conditional breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute MixProject in :int.interpreted()

        # set
        abs_path = Path.absname("lib/mix_project.ex")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "condition" => "a == b"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert MixProject in :int.interpreted()

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, _]}
               ] = :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, 3)

        assert {%Macro.Env{}, "a == b", nil, "0", 0} = BreakpointCondition.get_condition(0)

        # modify

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "condition" => "x == y"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] ==
                 :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, 3)

        assert {%Macro.Env{}, "x == y", nil, "0", 0} = BreakpointCondition.get_condition(0)

        # unset

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] == :int.all_breaks(MixProject)

        assert %{} == :sys.get_state(server).breakpoints

        refute BreakpointCondition.has_condition?(MixProject, [3])
      end)
    end

    @tag :fixture
    test "sets, modifies and unsets hit conditions", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute MixProject in :int.interpreted()

        # set
        abs_path = Path.absname("lib/mix_project.ex")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "hitCondition" => "25"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert MixProject in :int.interpreted()

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, _]}
               ] = :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, 3)

        assert {%Macro.Env{}, "true", nil, "25", 0} = BreakpointCondition.get_condition(0)

        # modify

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "hitCondition" => "55"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] ==
                 :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, 3)

        assert {%Macro.Env{}, "true", nil, "55", 0} = BreakpointCondition.get_condition(0)

        # unset

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] == :int.all_breaks(MixProject)

        assert %{} == :sys.get_state(server).breakpoints

        refute BreakpointCondition.has_condition?(MixProject, [3])
      end)
    end

    @tag :fixture
    test "sets, modifies and unsets log message", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute MixProject in :int.interpreted()

        # set
        abs_path = Path.absname("lib/mix_project.ex")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "logMessage" => "breakpoint hit"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert MixProject in :int.interpreted()

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, _]}
               ] = :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, 3)

        assert {%Macro.Env{}, "true", "breakpoint hit", "0", 0} =
                 BreakpointCondition.get_condition(0)

        # modify

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "logMessage" => "abc"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] ==
                 :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, 3)

        assert {%Macro.Env{}, "true", "abc", "0", 0} = BreakpointCondition.get_condition(0)

        # unset

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] == :int.all_breaks(MixProject)

        assert %{} == :sys.get_state(server).breakpoints

        refute BreakpointCondition.has_condition?(MixProject, [3])
      end)
    end

    @tag :fixture
    test "breakpoint in protocol", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(
          server,
          initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
        )

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "ProtocolBreakpoints.go1()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))
        abs_path = Path.absname("lib/protocol_breakpoints.ex")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 2}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert Proto in :int.interpreted()

        assert [{{Proto, 2}, [:active, :enable, :null, _]}] = :int.all_breaks(Proto)

        assert %{^abs_path => [{[Proto], 2}]} =
                 :sys.get_state(server).breakpoints

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "breakpoint",
                         "threadId" => thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(7, thread_id))

        assert_receive response(_, 7, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 2,
                             "name" => "Proto.go/1",
                             "source" => %{"path" => ^abs_path}
                           },
                           _
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(server, continue_req(15, thread_id))
        assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "breakpoint",
                         "threadId" => ^thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(8, thread_id))

        assert_receive response(_, 8, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 2,
                             "name" => "Proto.go/1",
                             "source" => %{"path" => ^abs_path}
                           }
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(
          server,
          set_breakpoints_req(9, %{"path" => abs_path}, [])
        )

        assert_receive(response(_, 9, "setBreakpoints", %{"breakpoints" => []}), 5000)

        assert [] = :int.all_breaks(Proto)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end

    @tag :fixture
    test "breakpoint in protocol implementation", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(
          server,
          initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
        )

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "ProtocolBreakpoints.go1()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))
        abs_path = Path.absname("lib/protocol_breakpoints.ex")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 7}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert Proto.List in :int.interpreted()
        assert Proto.BitString in :int.interpreted()

        assert [{{Proto.List, 7}, [:active, :enable, :null, _]}] = :int.all_breaks(Proto.List)

        assert [{{Proto.BitString, 7}, [:active, :enable, :null, _]}] =
                 :int.all_breaks(Proto.BitString)

        assert %{^abs_path => [{[Proto.BitString, Proto.List], 7}]} =
                 :sys.get_state(server).breakpoints

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "breakpoint",
                         "threadId" => thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(7, thread_id))

        assert_receive response(_, 7, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 7,
                             "name" => "Proto.List.go/1",
                             "source" => %{"path" => ^abs_path}
                           },
                           _
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(server, continue_req(15, thread_id))
        assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "breakpoint",
                         "threadId" => ^thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(8, thread_id))

        assert_receive response(_, 8, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 7,
                             "name" => "Proto.BitString.go/1",
                             "source" => %{"path" => ^abs_path}
                           }
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(
          server,
          set_breakpoints_req(9, %{"path" => abs_path}, [])
        )

        assert_receive(response(_, 9, "setBreakpoints", %{"breakpoints" => []}), 5000)

        assert [] = :int.all_breaks(Proto.List)
        assert [] = :int.all_breaks(Proto.BitString)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end
  end

  describe "function breakpoints" do
    test "sets and unsets function breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute :hello in :int.interpreted()

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => ":hello.hello_world/0"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert :hello in :int.interpreted()
        assert [{{:hello, 5}, _}] = :int.all_breaks(:hello)
        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [
            %{"name" => ":hello.hello_world/0"},
            %{"name" => "Some.with_multi_clauses/1"}
          ])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{
            "breakpoints" => [%{"verified" => true}, %{"verified" => true}]
          }),
          5000
        )

        assert Some in :int.interpreted()
        assert [{{:hello, 5}, _}] = :int.all_breaks(:hello)
        assert [{{Some, 74}, _}, {{Some, 78}, _}] = :int.all_breaks(Some)

        assert %{{Some, :with_multi_clauses, 1} => [74, 78], {:hello, :hello_world, 0} => [5]} =
                 :sys.get_state(server).function_breakpoints

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => "MixProject.quadruple/1"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert [] = :int.all_breaks(:hello)
        assert [{{MixProject, 3}, _}] = :int.all_breaks(MixProject)
        assert %{{MixProject, :quadruple, 1} => [3]} = :sys.get_state(server).function_breakpoints
      end)
    end

    test "handles invalid requests", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute :hello in :int.interpreted()

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => ":hello1.hello_world/0"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => false}]}),
          5000
        )

        Server.receive_packet(
          server,
          set_function_breakpoints_req(4, [%{"name" => ":hello.hello_world1/0"}])
        )

        assert_receive(
          response(_, 4, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => false}]}),
          5000
        )
      end)
    end

    test "sets, modifies and unsets conditional function breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute :hello in :int.interpreted()

        # set

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [
            %{"name" => ":hello.hello_world/0", "condition" => "a == b"}
          ])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert :hello in :int.interpreted()

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, 5)

        assert {%Macro.Env{}, "a == b", nil, "0", 0} = BreakpointCondition.get_condition(0)

        # update

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [
            %{"name" => ":hello.hello_world/0", "condition" => "x == y"}
          ])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{
            "breakpoints" => [%{"verified" => true}]
          }),
          5000
        )

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, 5)

        assert {%Macro.Env{}, "x == y", nil, "0", 0} = BreakpointCondition.get_condition(0)

        # unset

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).function_breakpoints

        refute BreakpointCondition.has_condition?(:hello, [5])
      end)
    end

    test "sets, modifies and unsets hit condition on function breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            # disable auto interpret
            "debugAutoInterpretAllModules" => false
          })
        )

        assert_receive(response(_, 2, "launch", _), 3000)
        assert_receive(event(_, "initialized", _), 5000)

        Process.sleep(100)

        refute :hello in :int.interpreted()

        # set

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [
            %{"name" => ":hello.hello_world/0", "hitCondition" => "25"}
          ])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert :hello in :int.interpreted()

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, 5)

        assert {%Macro.Env{}, "true", nil, "25", 0} = BreakpointCondition.get_condition(0)

        # update

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [
            %{"name" => ":hello.hello_world/0", "hitCondition" => "55"}
          ])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{
            "breakpoints" => [%{"verified" => true}]
          }),
          5000
        )

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, 5)

        assert {%Macro.Env{}, "true", nil, "55", 0} = BreakpointCondition.get_condition(0)

        # unset

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => []}),
          5000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).function_breakpoints

        refute BreakpointCondition.has_condition?(:hello, [5])
      end)
    end

    @tag :fixture
    test "breaks on function breakpoint", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "MixProject.exit_self()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => "MixProject.exit_self/0"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))

        Server.receive_packet(server, request(6, "threads", %{}))
        assert_receive(response(_, 6, "threads", %{"threads" => threads}))
        # ensure thread ids are unique
        thread_ids = Enum.map(threads, & &1["id"])
        assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "function breakpoint",
                         "threadId" => _thread_id
                       }),
                       5000
      end)
    end

    @tag :fixture
    test "function breakpoint in protocol", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(
          server,
          initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
        )

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "ProtocolBreakpoints.go1()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))
        abs_path = Path.absname("lib/protocol_breakpoints.ex")

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => "Proto.go/1"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert Proto in :int.interpreted()

        assert [
                 {{Proto, 2}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(Proto)

        assert %{{Proto, :go, 1} => [2]} = :sys.get_state(server).function_breakpoints

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "function breakpoint",
                         "threadId" => thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(7, thread_id))

        assert_receive response(_, 7, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 2,
                             "name" => "Proto.go/1",
                             "source" => %{"path" => ^abs_path}
                           },
                           _
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(server, continue_req(15, thread_id))
        assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "function breakpoint",
                         "threadId" => ^thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(8, thread_id))

        assert_receive response(_, 8, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 2,
                             "name" => "Proto.go/1",
                             "source" => %{"path" => ^abs_path}
                           }
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(
          server,
          set_function_breakpoints_req(9, [])
        )

        assert_receive(response(_, 9, "setFunctionBreakpoints", %{"breakpoints" => []}), 5000)

        assert [] = :int.all_breaks(Proto)
        assert %{} == :sys.get_state(server).function_breakpoints
      end)
    end

    @tag :fixture
    test "function breakpoint in protocol implementation", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(
          server,
          initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
        )

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "ProtocolBreakpoints.go1()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))
        abs_path = Path.absname("lib/protocol_breakpoints.ex")

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => "Proto.List.go/1"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert Proto.List in :int.interpreted()

        assert [
                 {{Proto.List, 7}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(Proto.List)

        assert %{{Proto.List, :go, 1} => [7]} = :sys.get_state(server).function_breakpoints

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "function breakpoint",
                         "threadId" => thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(7, thread_id))

        assert_receive response(_, 7, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 7,
                             "name" => "Proto.List.go/1",
                             "source" => %{"path" => ^abs_path}
                           },
                           _
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(
          server,
          set_function_breakpoints_req(9, [])
        )

        assert_receive(response(_, 9, "setFunctionBreakpoints", %{"breakpoints" => []}), 5000)

        assert [] = :int.all_breaks(Proto.List)
        assert %{} == :sys.get_state(server).function_breakpoints
      end)
    end

    @tag :fixture
    test "function breakpoint in derived protocol implementation", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(
          server,
          initialize_req_(1, %{initialize_req_args() |
          supports_variable_paging: true,
          supports_variable_type: true
        })
        )

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "ProtocolBreakpoints.go2()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))
        abs_path = Path.absname("lib/protocol_breakpoints.ex")

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => "DerivedProto.MyStruct.go/1"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          5000
        )

        assert DerivedProto.MyStruct in :int.interpreted()

        assert [
                 {{DerivedProto.MyStruct, 33},
                  [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(DerivedProto.MyStruct)

        assert %{{DerivedProto.MyStruct, :go, 1} => [33]} =
                 :sys.get_state(server).function_breakpoints

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))

        assert_receive event(_, "stopped", %{
                         "allThreadsStopped" => false,
                         "reason" => "function breakpoint",
                         "threadId" => thread_id
                       }),
                       5_000

        Server.receive_packet(server, stacktrace_req(7, thread_id))

        assert_receive response(_, 7, "stackTrace", %{
                         "stackFrames" => [
                           %{
                             "column" => 0,
                             "id" => frame_id,
                             "line" => 33,
                             "name" => "DerivedProto.MyStruct.go/1",
                             "source" => %{"path" => ^abs_path}
                           }
                         ]
                       })
                       when is_integer(frame_id)

        Server.receive_packet(
          server,
          set_function_breakpoints_req(9, [])
        )

        assert_receive(response(_, 9, "setFunctionBreakpoints", %{"breakpoints" => []}), 5000)

        assert [] = :int.all_breaks(DerivedProto.MyStruct)
        assert %{} == :sys.get_state(server).function_breakpoints
      end)
    end
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    describe "Kernel.dbg breakpoints" do
      test "breaks on dbg", %{server: server} do
        in_fixture(__DIR__, "mix_project", fn ->
          abs_path = Path.absname("lib/dbg.ex")
          Server.receive_packet(server, initialize_req_(1))
          assert_receive(response(_, 1, "initialize", _))

          Server.receive_packet(
            server,
            launch_req(2, %{
              "request" => "launch",
              "type" => "mix_task",
              "task" => "run",
              "taskArgs" => ["-e", "MixProject.Dbg.simple()"],
              "projectDir" => File.cwd!()
            })
          )

          assert_receive(response(_, 2, "launch", _), 3000)
          assert_receive(event(_, "initialized", _), 5000)

          Process.sleep(100)

          assert MixProject.Dbg in :int.interpreted()

          Server.receive_packet(server, request(5, "configurationDone", %{}))
          assert_receive(response(_, 5, "configurationDone", %{}))

          Server.receive_packet(server, request(6, "threads", %{}))
          assert_receive(response(_, 6, "threads", %{"threads" => threads}))

          # ensure thread ids are unique
          thread_ids = Enum.map(threads, & &1["id"])
          assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(7, thread_id))

          assert_receive response(_, 7, "stackTrace", %{
                           "totalFrames" => 1,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 5,
                               "name" => "MixProject.Dbg.simple/0",
                               "source" => %{"path" => ^abs_path}
                             }
                           ]
                         })
                         when is_integer(frame_id)

          Server.receive_packet(server, scopes_req(8, frame_id))

          assert_receive response(_, 8, "scopes", %{
                           "scopes" => [
                             %{
                               "expensive" => false,
                               "indexedVariables" => 0,
                               "name" => "variables",
                               "namedVariables" => 1,
                               "variablesReference" => vars_id
                             },
                             %{
                               "expensive" => false,
                               "indexedVariables" => 0,
                               "name" => "process info",
                               "namedVariables" => _,
                               "variablesReference" => _
                             }
                           ]
                         })

          Server.receive_packet(server, vars_req(9, vars_id))

          assert_receive response(_, 9, "variables", %{
                           "variables" => [
                             %{
                               "name" => "a",
                               "value" => "5",
                               "variablesReference" => 0
                             }
                           ]
                         }),
                         1000

          # stepIn is not supported
          Server.receive_packet(server, step_in_req(12, thread_id))

          assert_receive(
            error_response(
              _,
              12,
              "stepIn",
              "notSupported",
              "Kernel.dbg breakpoints do not support {command} command",
              %{"command" => "stepIn"},
              _,
              _
            )
          )

          # stepOut is not supported
          Server.receive_packet(server, step_out_req(13, thread_id))

          assert_receive(
            error_response(
              _,
              13,
              "stepOut",
              "notSupported",
              "Kernel.dbg breakpoints do not support {command} command",
              %{"command" => "stepOut"},
              _,
              _
            )
          )

          # next results in continue
          Server.receive_packet(server, next_req(14, thread_id))
          assert_receive response(_, 14, "next", %{})

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => ^thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(141, thread_id))

          assert_receive response(_, 141, "stackTrace", %{
                           "totalFrames" => 1,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 6,
                               "name" => "MixProject.Dbg.simple/0",
                               "source" => %{"path" => ^abs_path}
                             }
                           ]
                         })
                         when is_integer(frame_id)

          # continue
          Server.receive_packet(server, continue_req(15, thread_id))
          assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => ^thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(151, thread_id))

          assert_receive response(_, 151, "stackTrace", %{
                           "totalFrames" => 1,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 7,
                               "name" => "MixProject.Dbg.simple/0",
                               "source" => %{"path" => ^abs_path}
                             }
                           ]
                         })
                         when is_integer(frame_id)

          Server.receive_packet(server, continue_req(16, thread_id))
          assert_receive response(_, 16, "continue", %{"allThreadsContinued" => true})

          refute_receive event(_, "thread", %{
                           "reason" => "exited",
                           "threadId" => ^thread_id
                         }),
                         1_000
        end)
      end

      test "stepping through pipe", %{server: server} do
        in_fixture(__DIR__, "mix_project", fn ->
          abs_path = Path.absname("lib/dbg.ex")
          Server.receive_packet(server, initialize_req_(1))
          assert_receive(response(_, 1, "initialize", _))

          Server.receive_packet(
            server,
            launch_req(2, %{
              "request" => "launch",
              "type" => "mix_task",
              "task" => "run",
              "taskArgs" => ["-e", "MixProject.Dbg.pipe()"],
              "projectDir" => File.cwd!()
            })
          )

          assert_receive(response(_, 2, "launch", _), 3000)
          assert_receive(event(_, "initialized", _), 5000)

          Process.sleep(100)

          assert MixProject.Dbg in :int.interpreted()

          Server.receive_packet(server, request(5, "configurationDone", %{}))
          assert_receive(response(_, 5, "configurationDone", %{}))

          Server.receive_packet(server, request(6, "threads", %{}))
          assert_receive(response(_, 6, "threads", %{"threads" => threads}))

          # ensure thread ids are unique
          thread_ids = Enum.map(threads, & &1["id"])
          assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(7, thread_id))

          assert_receive response(_, 7, "stackTrace", %{
                           "totalFrames" => 1,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 14,
                               "name" => "MixProject.Dbg.pipe/0",
                               "source" => %{"path" => ^abs_path}
                             }
                           ]
                         })
                         when is_integer(frame_id)

          Server.receive_packet(server, scopes_req(8, frame_id))

          assert_receive response(_, 8, "scopes", %{
                           "scopes" => [
                             %{
                               "expensive" => false,
                               "indexedVariables" => 0,
                               "name" => "variables",
                               "namedVariables" => 1,
                               "variablesReference" => vars_id
                             },
                             %{
                               "expensive" => false,
                               "indexedVariables" => 0,
                               "name" => "process info",
                               "namedVariables" => _,
                               "variablesReference" => _
                             }
                           ]
                         })

          Server.receive_packet(server, vars_req(9, vars_id))

          assert_receive response(_, 9, "variables", %{
                           "variables" => [
                             %{
                               "name" => "a",
                               "value" => "5",
                               "variablesReference" => 0
                             }
                           ]
                         }),
                         1000

          # stepIn is not supported
          Server.receive_packet(server, step_in_req(12, thread_id))

          assert_receive(
            error_response(
              _,
              12,
              "stepIn",
              "notSupported",
              "Kernel.dbg breakpoints do not support {command} command",
              %{"command" => "stepIn"},
              _,
              _
            )
          )

          # stepOut is not supported
          Server.receive_packet(server, step_out_req(13, thread_id))

          assert_receive(
            error_response(
              _,
              13,
              "stepOut",
              "notSupported",
              "Kernel.dbg breakpoints do not support {command} command",
              %{"command" => "stepOut"},
              _,
              _
            )
          )

          # next steps through pipe
          Server.receive_packet(server, next_req(14, thread_id))
          assert_receive response(_, 14, "next", %{})

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => ^thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(141, thread_id))

          assert_receive response(_, 141, "stackTrace", %{
                           "totalFrames" => 1,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 15,
                               "name" => "MixProject.Dbg.pipe/0",
                               "source" => %{"path" => ^abs_path}
                             }
                           ]
                         })
                         when is_integer(frame_id)

          # continue skips pipe steps
          Server.receive_packet(server, continue_req(15, thread_id))
          assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

          refute_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => ^thread_id
                         }),
                         1_000

          refute_receive event(_, "thread", %{
                           "reason" => "exited",
                           "threadId" => ^thread_id
                         })
        end)
      end

      test "breaks on dbg when module is not interpreted", %{server: server} do
        in_fixture(__DIR__, "mix_project", fn ->
          abs_path = Path.absname("lib/dbg.ex")
          Server.receive_packet(server, initialize_req_(1))
          assert_receive(response(_, 1, "initialize", _))

          Server.receive_packet(
            server,
            launch_req(2, %{
              "request" => "launch",
              "type" => "mix_task",
              "task" => "run",
              "taskArgs" => ["-e", "MixProject.Dbg.simple()"],
              "projectDir" => File.cwd!(),
              # disable auto interpret
              "debugAutoInterpretAllModules" => false
            })
          )

          assert_receive(response(_, 2, "launch", _), 3000)
          assert_receive(event(_, "initialized", _), 5000)

          Process.sleep(100)

          refute MixProject.Dbg in :int.interpreted()

          Server.receive_packet(server, request(5, "configurationDone", %{}))
          assert_receive(response(_, 5, "configurationDone", %{}))

          Server.receive_packet(server, request(6, "threads", %{}))
          assert_receive(response(_, 6, "threads", %{"threads" => threads}))

          # ensure thread ids are unique
          thread_ids = Enum.map(threads, & &1["id"])
          assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(7, thread_id))

          assert_receive response(_, 7, "stackTrace", %{
                           "totalFrames" => 7,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 5,
                               "name" => "MixProject.Dbg.simple/0",
                               "source" => %{"path" => ^abs_path}
                             }
                             | _
                           ]
                         })
                         when is_integer(frame_id)

          Server.receive_packet(server, scopes_req(8, frame_id))

          assert_receive response(_, 8, "scopes", %{
                           "scopes" => [
                             %{
                               "expensive" => false,
                               "indexedVariables" => 0,
                               "name" => "variables",
                               "namedVariables" => 1,
                               "variablesReference" => vars_id
                             },
                             %{
                               "expensive" => false,
                               "indexedVariables" => 0,
                               "name" => "process info",
                               "namedVariables" => _,
                               "variablesReference" => _
                             }
                           ]
                         })

          Server.receive_packet(server, vars_req(9, vars_id))

          assert_receive response(_, 9, "variables", %{
                           "variables" => [
                             %{
                               "name" => "a",
                               "value" => "5",
                               "variablesReference" => 0
                             }
                           ]
                         }),
                         1000

          # stepIn is not supported
          Server.receive_packet(server, step_in_req(12, thread_id))

          assert_receive(
            error_response(
              _,
              12,
              "stepIn",
              "notSupported",
              "Kernel.dbg breakpoints do not support {command} command",
              %{"command" => "stepIn"},
              _,
              _
            )
          )

          # stepOut is not supported
          Server.receive_packet(server, step_out_req(13, thread_id))

          assert_receive(
            error_response(
              _,
              13,
              "stepOut",
              "notSupported",
              "Kernel.dbg breakpoints do not support {command} command",
              %{"command" => "stepOut"},
              _,
              _
            )
          )

          # next results in continue
          Server.receive_packet(server, next_req(14, thread_id))
          assert_receive response(_, 14, "next", %{})

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => ^thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(141, thread_id))

          assert_receive response(_, 141, "stackTrace", %{
                           "totalFrames" => 7,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 6,
                               "name" => "MixProject.Dbg.simple/0",
                               "source" => %{"path" => ^abs_path}
                             }
                             | _
                           ]
                         })
                         when is_integer(frame_id)

          # continue
          Server.receive_packet(server, continue_req(15, thread_id))
          assert_receive response(_, 15, "continue", %{"allThreadsContinued" => true})

          assert_receive event(_, "stopped", %{
                           "allThreadsStopped" => false,
                           "reason" => "breakpoint",
                           "threadId" => ^thread_id
                         }),
                         5_000

          Server.receive_packet(server, stacktrace_req(151, thread_id))

          assert_receive response(_, 151, "stackTrace", %{
                           "totalFrames" => 7,
                           "stackFrames" => [
                             %{
                               "column" => 0,
                               "id" => frame_id,
                               "line" => 7,
                               "name" => "MixProject.Dbg.simple/0",
                               "source" => %{"path" => ^abs_path}
                             }
                             | _
                           ]
                         })
                         when is_integer(frame_id)

          Server.receive_packet(server, continue_req(16, thread_id))
          assert_receive response(_, 16, "continue", %{"allThreadsContinued" => true})

          refute_receive event(_, "thread", %{
                           "reason" => "exited",
                           "threadId" => ^thread_id
                         }),
                         1_000
        end)
      end
    end
  end

  @tag :fixture
  test "server tracks running processes", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "run",
          "taskArgs" => ["-e", "MixProject.Some.sleep()"],
          "projectDir" => File.cwd!()
        })
      )

      assert_receive(response(_, 2, "launch", %{}), 5000)
      assert_receive(event(_, "initialized", _))

      Server.receive_packet(server, request(5, "configurationDone", %{}))
      assert_receive(response(_, 5, "configurationDone", %{}))
      Process.sleep(1000)

      {:ok, pid} =
        Task.start(fn ->
          receive do
            :done -> :ok
          end
        end)

      Process.monitor(pid)

      send(server, :update_threads)
      state = :sys.get_state(server)

      thread_id = state.pids_to_thread_ids[pid]
      assert thread_id
      assert state.thread_ids_to_pids[thread_id] == pid

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)

      if Version.match?(System.version(), ">= 1.15.0") do
        assert Enum.find(threads, &(&1["id"] == thread_id))["name"] ==
                 "Task.Supervised.noreply/4 #{:erlang.pid_to_list(pid)}"
      else
        assert Enum.find(threads, &(&1["id"] == thread_id))["name"] ==
                 ":proc_lib.init_p/5 #{:erlang.pid_to_list(pid)}"
      end

      send(pid, :done)

      receive do
        {:DOWN, _, _, ^pid, _} -> :ok
      end

      send(server, :update_threads)
      state = :sys.get_state(server)

      refute Map.has_key?(state.pids_to_thread_ids, pid)
      refute Map.has_key?(state.thread_ids_to_pids, thread_id)

      Server.receive_packet(server, request(6, "threads", %{}))
      assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)

      refute Enum.find(threads, &(&1["id"] == thread_id))
    end)
  end

  if System.otp_release() |> String.to_integer() >= 27 do
    @tag :fixture
    test "returns process label", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "run",
            "taskArgs" => ["-e", "MixProject.Some.sleep()"],
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)
        assert_receive(event(_, "initialized", _))

        Server.receive_packet(server, request(5, "configurationDone", %{}))
        assert_receive(response(_, 5, "configurationDone", %{}))
        Process.sleep(1000)

        {:ok, pid} =
          Task.start(fn ->
            :proc_lib.set_label("foo")

            receive do
              :done -> :ok
            end
          end)

        Process.monitor(pid)

        send(server, :update_threads)
        state = :sys.get_state(server)

        thread_id = state.pids_to_thread_ids[pid]
        assert thread_id
        assert state.thread_ids_to_pids[thread_id] == pid

        Server.receive_packet(server, request(6, "threads", %{}))
        assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)

        assert Enum.find(threads, &(&1["id"] == thread_id))["name"] ==
                 "\"foo\" #{:erlang.pid_to_list(pid)}"

        send(pid, :done)

        receive do
          {:DOWN, _, _, ^pid, _} -> :ok
        end

        send(server, :update_threads)
        state = :sys.get_state(server)

        refute Map.has_key?(state.pids_to_thread_ids, pid)
        refute Map.has_key?(state.thread_ids_to_pids, thread_id)

        Server.receive_packet(server, request(6, "threads", %{}))
        assert_receive(response(_, 6, "threads", %{"threads" => threads}), 1_000)

        refute Enum.find(threads, &(&1["id"] == thread_id))
      end)
    end
  end

  describe "evaluate" do
    defp gen_watch_expression_packet(seq, expr) do
      %{
        "arguments" => %{
          "context" => "watch",
          "expression" => expr,
          "frameId" => nil
        },
        "command" => "evaluate",
        "seq" => seq,
        "type" => "request"
      }
    end

    test "evaluate expression with OK result", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1, %{initialize_req_args() |
          supports_progress_reporting: true
        }))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, "1 + 2 + 3 + 4")
        )

        assert_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => "1 + 2 + 3 + 4",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        assert_receive(%{"body" => %{"result" => "10"}}, 1000)

        assert_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    test "evaluate expression with OK result - progress reporting not supported", %{
      server: server
    } do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, "1 + 2 + 3 + 4")
        )

        refute_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => "1 + 2 + 3 + 4",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        assert_receive(%{"body" => %{"result" => "10"}}, 1000)

        refute_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    @tag :capture_log
    test "evaluate expression with exception result", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1, %{initialize_req_args() |
          supports_progress_reporting: true
        }))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, "1 = 2")
        )

        assert_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => "1 = 2",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        assert_receive(
          error_response(
            _,
            1,
            "evaluate",
            "evaluateError",
            "** (MatchError) no match of right hand side value: 2" <> _,
            %{},
            _,
            _
          )
        )

        assert_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    test "evaluate expression which calls exit process", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1, %{initialize_req_args() |
          supports_progress_reporting: true
        }))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, "exit(:normal)")
        )

        assert_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => "exit(:normal)",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        # evaluator process exits so we should not get a response
        refute_receive(%{"body" => %{"result" => _result}}, 1000)

        assert_receive(
          error_response(
            _,
            1,
            "evaluate",
            "evaluateError",
            "** (exit) normal" <> _,
            %{},
            _,
            _
          )
        )

        assert_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    test "evaluate expression with attempt to exit debugger process", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1, %{initialize_req_args() |
          supports_progress_reporting: true
        }))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, "Process.exit(self(), :normal)")
        )

        assert_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => "Process.exit(self(), :normal)",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        # evaluator process exits so we should not get a response
        refute_receive(%{"body" => %{"result" => _result}}, 1000)

        assert_receive(
          error_response(
            _,
            1,
            "evaluate",
            "internalServerError",
            "Request handler exited with reason normal",
            %{},
            _,
            _
          )
        )

        assert_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    test "evaluate expression with attempt to exit debugger process - progress not supported", %{
      server: server
    } do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, "Process.exit(self(), :normal)")
        )

        refute_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => "Process.exit(self(), :normal)",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        # evaluator process exits so we should not get a response
        refute_receive(%{"body" => %{"result" => _result}}, 1000)

        assert_receive(
          error_response(
            _,
            1,
            "evaluate",
            "internalServerError",
            "Request handler exited with reason normal",
            %{},
            _,
            _
          )
        )

        refute_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    test "evaluate expression with attempt to throw debugger process", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1, %{initialize_req_args() |
          supports_progress_reporting: true
        }))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, "throw(:goodmorning_bug)")
        )

        assert_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => "throw(:goodmorning_bug)",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        assert_receive(
          error_response(
            _,
            1,
            "evaluate",
            "evaluateError",
            "** (throw) :goodmorning_bug" <> _,
            %{},
            _,
            _
          )
        )

        assert_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    test "evaluate expression which has long execution", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1, %{initialize_req_args() |
          supports_progress_reporting: true
        }))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, ":timer.sleep(10_000)")
        )

        assert_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => ":timer.sleep(10_000)",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        Server.receive_packet(
          server,
          cancel_req(2, %{"progressId" => "1"})
        )

        assert_receive(response(_, 2, "cancel", _))

        assert_receive(
          error_response(
            _,
            1,
            "evaluate",
            "cancelled",
            "cancelled",
            %{},
            _,
            _
          )
        )

        assert_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end

    test "evaluate expression which has long execution - progress not supported", %{
      server: server
    } do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req_(1))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!()
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)

        Server.receive_packet(
          server,
          gen_watch_expression_packet(1, ":timer.sleep(10_000)")
        )

        refute_receive(
          event(_, "progressStart", %{
            "cancellable" => true,
            "message" => ":timer.sleep(10_000)",
            "progressId" => "1",
            "requestId" => 1,
            "title" => "Evaluating expression"
          })
        )

        Server.receive_packet(
          server,
          cancel_req(2, %{"requestId" => 1})
        )

        assert_receive(response(_, 2, "cancel", _))

        assert_receive(
          error_response(
            _,
            1,
            "evaluate",
            "cancelled",
            "cancelled",
            %{},
            _,
            _
          )
        )

        refute_receive(event(_, "progressEnd", %{"progressId" => "1"}))

        assert Process.alive?(server)
      end)
    end
  end

  test "completions", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", _))

      Server.receive_packet(
        server,
        %{
          "arguments" => %{
            "text" => "DateTi",
            "column" => 7
          },
          "command" => "completions",
          "seq" => 1,
          "type" => "request"
        }
      )

      assert_receive(%{"body" => %{"targets" => _targets}}, 10000)

      assert Process.alive?(server)
    end)
  end

  test "completions cancel", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", _))

      Server.receive_packet(
        server,
        %{
          "arguments" => %{
            "text" => "DateTi",
            "column" => 7
          },
          "command" => "completions",
          "seq" => 1,
          "type" => "request"
        }
      )

      Server.receive_packet(
        server,
        cancel_req(2, %{"requestId" => 1})
      )

      assert_receive(response(_, 2, "cancel", _))

      assert_receive(
        error_response(
          _,
          1,
          "completions",
          "cancelled",
          "cancelled",
          %{},
          _,
          _
        )
      )

      assert Process.alive?(server)
    end)
  end

  test "cancel not existing request", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", _))

      Server.receive_packet(
        server,
        cancel_req(2, %{"requestId" => 1})
      )

      assert_receive(
        error_response(
          _,
          2,
          "cancel",
          "invalidRequest",
          "Request or progress {reguestOrProgressId} cannot be cancelled",
          %{"reguestOrProgressId" => "1"},
          _,
          _
        )
      )

      assert Process.alive?(server)
    end)
  end

  test "source", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req_(1))
      assert_receive(response(_, 1, "initialize", _))

      Server.receive_packet(
        server,
        %{
          "arguments" => %{
            "sourceReference" => 0,
            "source" => %{"path" => "lib/crash.ex"}
          },
          "command" => "source",
          "seq" => 1,
          "type" => "request"
        }
      )

      assert_receive(%{"body" => %{"content" => "defmodule MixProject.Crash do" <> _}}, 10000)

      Server.receive_packet(
        server,
        %{
          "arguments" => %{
            "sourceReference" => 0,
            "source" => %{"path" => "replinput"}
          },
          "command" => "source",
          "seq" => 1,
          "type" => "request"
        }
      )

      assert_receive(%{"body" => %{"content" => ""}}, 10000)

      assert Process.alive?(server)
    end)
  end
end
