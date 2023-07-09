defmodule ElixirLS.Debugger.ServerTest do
  # Awkwardly, testing that the debugger can debug ExUnit tests in the fixture project
  # gives us no way to capture the output, since ExUnit doesn't really distinguish
  # between the debugger's tests and the fixture project's tests. Expect to see output printed
  # from both.

  alias ElixirLS.Debugger.{Server, Protocol, BreakpointCondition}
  use ElixirLS.Utils.MixTest.Case, async: false
  use Protocol

  doctest ElixirLS.Debugger.Server

  setup do
    {:ok, packet_capture} = ElixirLS.Utils.PacketCapture.start_link(self())
    Process.group_leader(Process.whereis(ElixirLS.Debugger.Output), packet_capture)

    {:ok, server} = Server.start_link()

    on_exit(fn ->
      for mod <- :int.interpreted(), do: :int.nn(mod)
      :int.auto_attach(false)
      :int.no_break()
      :int.clear()
      BreakpointCondition.clear()
    end)

    {:ok, %{server: server}}
  end

  describe "initialize" do
    test "succeeds", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{"clientID" => "some_id"}))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        assert :sys.get_state(server).client_info == %{"clientID" => "some_id"}
      end)
    end

    test "fails when already initialized", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{"clientID" => "some_id"}))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(server, initialize_req(2, %{"clientID" => "some_id"}))

        assert_receive(
          error_response(
            _,
            2,
            "initialize",
            "invalidRequest",
            "Debugger request {command} was not expected",
            %{"command" => "initialize"}
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
            "Debugger request {command} was not expected",
            %{"command" => "setBreakpoints"}
          )
        )
      end)
    end
  end

  describe "disconnect" do
    test "succeeds when not initialized", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Process.flag(:trap_exit, true)
        Server.receive_packet(server, request(1, "disconnect"))
        assert_receive(response(_, 1, "disconnect", %{}))
        assert_receive({:EXIT, ^server, {:exit_code, 0}})
        Process.flag(:trap_exit, false)
      end)
    end

    test "succeeds when initialized", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Process.flag(:trap_exit, true)
        Server.receive_packet(server, initialize_req(1, %{"clientID" => "some_id"}))

        assert_receive(
          response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true})
        )

        Server.receive_packet(server, request(2, "disconnect"))
        assert_receive(response(_, 2, "disconnect", %{}))
        assert_receive({:EXIT, ^server, {:exit_code, 0}})
        Process.flag(:trap_exit, false)
      end)
    end
  end

  @tag :fixture
  test "basic debugging", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req(1, %{
          "supportsVariablePaging" => true,
          "supportsVariableType" => true
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
      assert_receive(event(_, "initialized", %{}))
      abs_path = Path.absname("lib/mix_project.ex")

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 50}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]})
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
                           "name" => _,
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
    end)
  end

  @tag :fixture
  test "multiple paused processes", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req(1, %{
          "supportsVariablePaging" => true,
          "supportsVariableType" => true
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
      assert_receive(event(_, "initialized", %{}))
      abs_path = Path.absname("lib/mix_project.ex")

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 67}, %{"line" => 70}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{
          "breakpoints" => [%{"verified" => true}, %{"verified" => true}]
        })
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
      Server.receive_packet(server, initialize_req(1, %{}))
      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

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
      assert_receive(event(_, "initialized", %{}))

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => Path.absname("lib/mix_project.ex")}, [%{"line" => 3}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]})
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

      Server.receive_packet(server, stacktrace_req(7, "not existing"))

      assert_receive error_response(
                       _,
                       7,
                       "stackTrace",
                       "invalidArgument",
                       "threadId not found: {threadId}",
                       %{"threadId" => "\"not existing\""}
                     )

      Server.receive_packet(server, scopes_req(8, "not existing"))

      assert_receive error_response(
                       _,
                       8,
                       "scopes",
                       "invalidArgument",
                       "frameId not found: {frameId}",
                       %{"frameId" => "\"not existing\""}
                     )

      Server.receive_packet(server, vars_req(9, "not existing"))

      assert_receive error_response(
                       _,
                       9,
                       "variables",
                       "invalidArgument",
                       "variablesReference not found: {variablesReference}",
                       %{"variablesReference" => "\"not existing\""}
                     )

      Server.receive_packet(server, next_req(10, "not existing"))

      assert_receive error_response(
                       _,
                       10,
                       "next",
                       "invalidArgument",
                       "threadId not found: {threadId}",
                       %{"threadId" => "\"not existing\""}
                     )

      Server.receive_packet(server, step_in_req(11, "not existing"))

      assert_receive error_response(
                       _,
                       11,
                       "stepIn",
                       "invalidArgument",
                       "threadId not found: {threadId}",
                       %{"threadId" => "\"not existing\""}
                     )

      Server.receive_packet(server, step_out_req(12, "not existing"))

      assert_receive error_response(
                       _,
                       12,
                       "stepOut",
                       "invalidArgument",
                       "threadId not found: {threadId}",
                       %{"threadId" => "\"not existing\""}
                     )

      Server.receive_packet(server, continue_req(13, "not existing"))

      assert_receive error_response(
                       _,
                       13,
                       "continue",
                       "invalidArgument",
                       "threadId not found: {threadId}",
                       %{"threadId" => "\"not existing\""}
                     )

      Server.receive_packet(server, request(14, "someRequest", %{"threadId" => 123}))

      assert_receive error_response(
                       _,
                       14,
                       "someRequest",
                       "notSupported",
                       "Debugger request {command} is currently not supported",
                       %{"command" => "someRequest"}
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
                       "process not paused: {threadId}",
                       %{"threadId" => ^thread_id_str}
                     )
    end)
  end

  @tag :fixture
  test "notifies about process exit", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req(1, %{}))
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
      assert_receive(event(_, "initialized", %{}))

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => Path.absname("lib/mix_project.ex")}, [%{"line" => 17}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
        1000
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
      Server.receive_packet(server, initialize_req(1, %{}))
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
      assert_receive(event(_, "initialized", %{}))

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => Path.absname("lib/mix_project.ex")}, [%{"line" => 29}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]})
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
      Server.receive_packet(server, initialize_req(1, %{}))
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
      assert_receive(event(_, "initialized", %{}))

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
        Server.receive_packet(server, initialize_req(1, %{}))

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
        assert_receive(event(_, "initialized", %{}))

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
                         "category" => "important",
                         "output" => "Failed to obtain meta for pid" <> _
                       })
      end)
    end

    @tag :fixture
    test "dead", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))

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
        assert_receive(event(_, "initialized", %{}))

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
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

        refute :hello in :int.interpreted()
        abs_path = Path.absname("src/hello.erl")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 5}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
        )

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
          3000
        )

        assert [{{:hello, 5}, _}, {{:hello, 6}, _}] = :int.all_breaks(:hello)

        assert %{^abs_path => [{[:hello], 5}, {[:hello], 6}]} = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 6}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
        )

        assert [{{:hello, 6}, _}] = :int.all_breaks(:hello)
        assert %{^abs_path => [{[:hello], 6}]} = :sys.get_state(server).breakpoints

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          3000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end

    @tag :fixture
    test "sets and unsets breakpoints in elixir modules", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

        refute MixProject in :int.interpreted()
        refute MixProject.Some in :int.interpreted()
        abs_path = Path.absname("lib/mix_project.ex")

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 3}])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
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
          3000
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
          3000
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
          3000
        )

        assert [] = :int.all_breaks(MixProject.Some)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end

    @tag :fixture
    test "sets and unsets breakpoints in different files", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

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
          3000
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
          3000
        )

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
          3000
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
          3000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).breakpoints
      end)
    end

    @tag :fixture
    test "sets, modifies and unsets conditional breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

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
          3000
        )

        assert MixProject in :int.interpreted()

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, _]}
               ] = :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, [3])

        assert BreakpointCondition.get_condition(0) == {"a == b", nil, 0, 0}

        # modify

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "condition" => "x == y"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
        )

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] ==
                 :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, [3])

        assert BreakpointCondition.get_condition(0) == {"x == y", nil, 0, 0}

        # unset

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          3000
        )

        assert [] == :int.all_breaks(MixProject)

        assert %{} == :sys.get_state(server).breakpoints

        refute BreakpointCondition.has_condition?(MixProject, [3])
      end)
    end

    @tag :fixture
    test "sets, modifies and unsets hit conditions", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

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
          3000
        )

        assert MixProject in :int.interpreted()

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, _]}
               ] = :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, [3])

        assert BreakpointCondition.get_condition(0) == {"true", nil, 25, 0}

        # modify

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "hitCondition" => "55"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
        )

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] ==
                 :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, [3])

        assert BreakpointCondition.get_condition(0) == {"true", nil, 55, 0}

        # unset

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          3000
        )

        assert [] == :int.all_breaks(MixProject)

        assert %{} == :sys.get_state(server).breakpoints

        refute BreakpointCondition.has_condition?(MixProject, [3])
      end)
    end

    @tag :fixture
    test "sets, modifies and unsets log message", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

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
          3000
        )

        assert MixProject in :int.interpreted()

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, _]}
               ] = :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, [3])

        assert BreakpointCondition.get_condition(0) == {"true", "breakpoint hit", 0, 0}

        # modify

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [
            %{"line" => 3, "logMessage" => "abc"}
          ])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
        )

        assert [
                 {{MixProject, 3}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] ==
                 :int.all_breaks(MixProject)

        assert %{^abs_path => [{[MixProject], 3}]} = :sys.get_state(server).breakpoints

        assert BreakpointCondition.has_condition?(MixProject, [3])

        assert BreakpointCondition.get_condition(0) == {"true", "abc", 0, 0}

        # unset

        Server.receive_packet(
          server,
          set_breakpoints_req(3, %{"path" => abs_path}, [])
        )

        assert_receive(
          response(_, 3, "setBreakpoints", %{"breakpoints" => []}),
          3000
        )

        assert [] == :int.all_breaks(MixProject)

        assert %{} == :sys.get_state(server).breakpoints

        refute BreakpointCondition.has_condition?(MixProject, [3])
      end)
    end
  end

  describe "function breakpoints" do
    test "sets and unsets function breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

        refute :hello in :int.interpreted()

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => ":hello.hello_world/0"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
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
          3000
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
          3000
        )

        assert [] = :int.all_breaks(:hello)
        assert [{{MixProject, 3}, _}] = :int.all_breaks(MixProject)
        assert %{{MixProject, :quadruple, 1} => [3]} = :sys.get_state(server).function_breakpoints
      end)
    end

    test "sets, modifies and unsets conditional function breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

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
          3000
        )

        assert :hello in :int.interpreted()

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, [5])

        assert BreakpointCondition.get_condition(0) == {"a == b", nil, 0, 0}

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
          3000
        )

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, [5])

        assert BreakpointCondition.get_condition(0) == {"x == y", nil, 0, 0}

        # unset

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => []}),
          3000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).function_breakpoints

        refute BreakpointCondition.has_condition?(:hello, [5])
      end)
    end

    test "sets, modifies and unsets hit condition on function breakpoints", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
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
        assert_receive(event(_, "initialized", %{}), 5000)

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
          3000
        )

        assert :hello in :int.interpreted()

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, [5])

        assert BreakpointCondition.get_condition(0) == {"true", nil, 25, 0}

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
          3000
        )

        assert [
                 {{:hello, 5}, [:active, :enable, :null, {BreakpointCondition, :check_0}]}
               ] = :int.all_breaks(:hello)

        assert %{{:hello, :hello_world, 0} => [5]} = :sys.get_state(server).function_breakpoints

        assert BreakpointCondition.has_condition?(:hello, [5])

        assert BreakpointCondition.get_condition(0) == {"true", nil, 55, 0}

        # unset

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => []}),
          3000
        )

        assert [] = :int.all_breaks(:hello)
        assert %{} == :sys.get_state(server).function_breakpoints

        refute BreakpointCondition.has_condition?(:hello, [5])
      end)
    end

    @tag :fixture
    test "breaks on function breakpoint", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))

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
        assert_receive(event(_, "initialized", %{}))

        Server.receive_packet(
          server,
          set_function_breakpoints_req(3, [%{"name" => "MixProject.exit_self/0"}])
        )

        assert_receive(
          response(_, 3, "setFunctionBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
          3000
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
  end

  @tag :fixture
  test "breakpoint in protocol implementation", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(
        server,
        initialize_req(1, %{
          "supportsVariablePaging" => true,
          "supportsVariableType" => true
        })
      )

      assert_receive(response(_, 1, "initialize", %{"supportsConfigurationDoneRequest" => true}))

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
      assert_receive(event(_, "initialized", %{}))
      abs_path = Path.absname("lib/protocol_breakpoints.ex")

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => abs_path}, [%{"line" => 7}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]})
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

      assert_receive(response(_, 9, "setBreakpoints", %{"breakpoints" => []}))

      assert [] = :int.all_breaks(Proto.List)
      assert [] = :int.all_breaks(Proto.BitString)
      assert %{} == :sys.get_state(server).breakpoints
    end)
  end

  @tag :fixture
  test "server tracks running processes", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req(1, %{}))

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
      assert_receive(event(_, "initialized", %{}))

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

      if Version.match?(System.version(), ">= 1.15.0-dev") do
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

  describe "Watch section" do
    defp gen_watch_expression_packet(expr) do
      %{
        "arguments" => %{
          "context" => "watch",
          "expression" => expr,
          "frameId" => 123
        },
        "command" => "evaluate",
        "seq" => 1,
        "type" => "request"
      }
    end

    test "Evaluate expression with OK result", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet("1 + 2 + 3 + 4")
        )

        assert_receive(%{"body" => %{"result" => "10"}}, 1000)

        assert Process.alive?(server)
      end)
    end

    @tag :capture_log
    test "Evaluate expression with ERROR result", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet("1 = 2")
        )

        assert_receive(%{"body" => %{"result" => result}}, 1000)

        assert result =~ ~r/badmatch/

        assert Process.alive?(server)
      end)
    end

    test "Evaluate expression with attempt to exit debugger process", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet("Process.exit(self(), :normal)")
        )

        assert_receive(%{"body" => %{"result" => result}}, 1000)

        assert result =~ ~r/:exit/

        assert Process.alive?(server)
      end)
    end

    test "Evaluate expression with attempt to throw debugger process", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          gen_watch_expression_packet("throw(:goodmorning_bug)")
        )

        assert_receive(%{"body" => %{"result" => result}}, 1000)

        assert result =~ ~r/:goodmorning_bug/

        assert Process.alive?(server)
      end)
    end

    test "Evaluate expression which has long execution", %{server: server} do
      in_fixture(__DIR__, "mix_project", fn ->
        Server.receive_packet(server, initialize_req(1, %{}))
        assert_receive(response(_, 1, "initialize", _))

        Server.receive_packet(
          server,
          launch_req(2, %{
            "request" => "launch",
            "type" => "mix_task",
            "task" => "test",
            "projectDir" => File.cwd!(),
            "debugExpressionTimeoutMs" => 500
          })
        )

        assert_receive(response(_, 2, "launch", %{}), 5000)

        Server.receive_packet(
          server,
          gen_watch_expression_packet(":timer.sleep(10_000)")
        )

        assert_receive(%{"body" => %{"result" => result}}, 1100)

        assert result =~ ~r/:elixir_ls_expression_timeout/

        assert Process.alive?(server)
      end)
    end
  end

  test "Completions", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req(1, %{}))
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
end
