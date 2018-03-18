defmodule ElixirLS.Debugger.ServerTest do
  # Awkwardly, testing that the debugger can debug ExUnit tests in the fixture project
  # gives us no way to capture the output, since ExUnit doesn't really distinguish
  # between the debugger's tests and the fixture project's tests. Expect to see output printed
  # from both.

  alias ElixirLS.Debugger.{Server, Protocol}
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
    end)

    {:ok, %{server: server}}
  end

  test "basic debugging", %{server: server} do
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
        set_breakpoints_req(3, %{"path" => "lib/mix_project.ex"}, [%{"line" => 3}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]})
      )

      Server.receive_packet(server, request(4, "configurationDone", %{}))
      assert_receive(response(_, 4, "configurationDone", %{}))

      Server.receive_packet(server, request(5, "threads", %{}))
      assert_receive(response(_, 5, "threads", %{"threads" => threads}))
      # ensure thread ids are unique
      thread_ids = Enum.map(threads, & &1["id"])
      assert Enum.count(Enum.uniq(thread_ids)) == Enum.count(thread_ids)

      assert_receive event(_, "stopped", %{
                       "allThreadsStopped" => false,
                       "reason" => "breakpoint",
                       "threadId" => thread_id
                     })

      Server.receive_packet(server, stacktrace_req(6, thread_id))

      assert_receive response(_, 6, "stackTrace", %{
                       "totalFrames" => 1,
                       "stackFrames" => [
                         %{
                           "column" => 0,
                           "id" => frame_id,
                           "line" => 3,
                           "name" => "MixProject.quadruple/1",
                           "source" => %{"path" => path}
                         }
                       ]
                     })
                     when is_integer(frame_id)

      assert String.ends_with?(path, "/lib/mix_project.ex")

      Server.receive_packet(server, scopes_req(7, frame_id))

      assert_receive response(_, 7, "scopes", %{
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
                           "indexedVariables" => 1,
                           "name" => "arguments",
                           "namedVariables" => 0,
                           "variablesReference" => _
                         }
                       ]
                     })

      Server.receive_packet(server, vars_req(8, vars_id))

      assert_receive response(_, 8, "variables", %{
                       "variables" => [
                         %{
                           "name" => "_x@1",
                           "type" => "integer",
                           "value" => "2",
                           "variablesReference" => 0
                         }
                       ]
                     })

      Server.receive_packet(server, continue_req(9, thread_id))
      assert_receive response(_, 9, "continue", %{"allThreadsContinued" => false})

      assert_receive(event(_, "exited", %{"exitCode" => 0}))
      assert_receive(event(_, "terminated", %{"restart" => false}))
    end)
  end

  test "sets breakpoints in erlang modules", %{server: server} do
    in_fixture(__DIR__, "mix_project", fn ->
      Server.receive_packet(server, initialize_req(1, %{}))

      Server.receive_packet(
        server,
        launch_req(2, %{
          "request" => "launch",
          "type" => "mix_task",
          "task" => "test",
          "projectDir" => File.cwd!()
        })
      )

      Server.receive_packet(
        server,
        set_breakpoints_req(3, %{"path" => "src/hello.erl"}, [%{"line" => 5}])
      )

      assert_receive(
        response(_, 3, "setBreakpoints", %{"breakpoints" => [%{"verified" => true}]}),
        1000
      )

      assert(:hello in :int.interpreted())
    end)
  end
end
