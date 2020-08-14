defmodule ElixirLS.LanguageServer.ServerTest do
  alias ElixirLS.LanguageServer.{Server, Protocol, SourceFile}
  alias ElixirLS.Utils.PacketCapture
  use ElixirLS.Utils.MixTest.Case, async: false
  use Protocol

  doctest(Server)

  defp initialize(server) do
    Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
    Server.receive_packet(server, notification("initialized"))

    Server.receive_packet(
      server,
      did_change_configuration(%{"elixirLS" => %{"dialyzerEnabled" => false}})
    )
  end

  defp root_uri do
    SourceFile.path_to_uri(File.cwd!())
  end

  setup context do
    unless context[:skip_server] do
      server = ElixirLS.LanguageServer.Test.ServerTestHelpers.start_server()

      {:ok, %{server: server}}
    else
      :ok
    end
  end

  test "textDocument/didChange when the client hasn't claimed ownership with textDocument/didOpen",
       %{server: server} do
    uri = "file:///file.ex"

    content_changes = [
      %{
        "range" => %{
          "end" => %{"character" => 2, "line" => 1},
          "start" => %{"character" => 0, "line" => 2}
        },
        "rangeLength" => 1,
        "text" => ""
      }
    ]

    version = 2

    Server.receive_packet(server, did_change(uri, version, content_changes))

    assert_receive %{
      "method" => "window/logMessage",
      "params" => %{
        "message" =>
          "Received textDocument/didChange for file that is not open. Received uri: \"file:///file.ex\"",
        "type" => 2
      }
    }

    # Wait for the server to process the message and ensure that there is no exception
    _ = :sys.get_state(server)
  end

  test "hover", %{server: server} do
    uri = "file:///file.ex"
    code = ~S(
      defmodule MyModule do
        use GenServer
      end
    )

    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, hover_req(1, uri, 2, 17))

    resp = assert_receive(%{"id" => 1}, 1000)

    assert response(1, %{
             "contents" => %{
               "kind" => "markdown",
               "value" => "> GenServer" <> _
             },
             "range" => %{
               "start" => %{"line" => 2, "character" => 12},
               "end" => %{"line" => 2, "character" => 21}
             }
           }) = resp
  end

  test "auto complete", %{server: server} do
    uri = "file:///file.ex"
    code = ~S(
    defmodule MyModule do
      def my_fn, do: GenSer
    end
    )

    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, completion_req(1, uri, 2, 25))

    resp = assert_receive(%{"id" => 1}, 1000)

    assert response(1, %{
             "isIncomplete" => true,
             "items" => [
               %{
                 "detail" => "behaviour",
                 "documentation" => _,
                 "kind" => 9,
                 "label" => "GenServer"
               }
               | _
             ]
           }) = resp
  end

  # Failing
  @tag :pending
  test "go to definition", %{server: server} do
    uri = "file:///file.ex"
    code = ~S(
      defmodule MyModule do
        use GenServer
      end
    )

    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, definition_req(1, uri, 2, 17))

    uri = "file://" <> to_string(GenServer.module_info()[:compile][:source])

    resp = assert_receive(%{"id" => 1}, 1000)

    assert response(1, %{
             "range" => %{
               "end" => %{"character" => column, "line" => 0},
               "start" => %{"character" => column, "line" => 0}
             },
             "uri" => ^uri
           }) = resp

    assert column > 0
  end

  test "requests cancellation", %{server: server} do
    Server.receive_packet(server, hover_req(1, "file:///file.ex", 1, 1))
    Server.receive_packet(server, cancel_request(1))

    assert_receive %{
      "error" => %{"code" => -32800, "message" => "Request cancelled"},
      "id" => 1,
      "jsonrpc" => "2.0"
    }
  end

  test "requests shutdown without params", %{server: server} do
    Server.receive_packet(server, request(1, "shutdown"))
    assert %{received_shutdown?: true} = :sys.get_state(server)
  end

  test "requests shutdown with params", %{server: server} do
    Server.receive_packet(server, request(1, "shutdown", nil))
    assert %{received_shutdown?: true} = :sys.get_state(server)
  end

  test "document symbols request when there are no client capabilities and the source file is not loaded into the server",
       %{server: server} do
    server_state = :sys.get_state(server)
    assert server_state.client_capabilities == nil
    assert server_state.source_files == %{}

    Server.receive_packet(server, document_symbol_req(1, "file:///file.ex"))

    resp = assert_receive(%{"id" => 1}, 1000)
    assert resp["result"] == []
  end

  test "incremental formatter", %{server: server} do
    in_fixture(__DIR__, "formatter", fn ->
      uri = Path.join([root_uri(), "file.ex"])

      code = """
      defmodule MyModule do
        def my_fn do
          foo("This should be split into two lines if reading options from .formatter.exs")
        end
      end
      """

      initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, formatting_req(2, uri, %{}))

      resp = assert_receive(%{"id" => 2}, 1000)

      assert response(2, [
               %{
                 "newText" => "\n    ",
                 "range" => %{
                   "end" => %{"character" => 84, "line" => 2},
                   "start" => %{"character" => 84, "line" => 2}
                 }
               },
               %{
                 "newText" => "\n      ",
                 "range" => %{
                   "end" => %{"character" => 8, "line" => 2},
                   "start" => %{"character" => 8, "line" => 2}
                 }
               }
             ]) == resp

      # Now try it in a subdirectory with its own .formatter.exs file that does not define a max line length.
      subdir_uri = Path.join([root_uri(), "lib/file.ex"])
      Server.receive_packet(server, did_open(subdir_uri, "elixir", 1, code))
      Server.receive_packet(server, formatting_req(3, subdir_uri, %{}))

      resp = assert_receive(%{"id" => 3}, 1000)

      # File is already formatted
      assert response(3, []) == resp
    end)
  end

  test "signature help", %{server: server} do
    uri = "file:///file.ex"
    code = ~S[
    defmodule MyModule do
      def my_fn do
        IO.inspect()
      end
    end
    ]

    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, signature_help_req(1, uri, 3, 19))

    resp = assert_receive(%{"id" => 1}, 1000)

    assert response(1, %{
             "activeParameter" => 0,
             "activeSignature" => 0,
             "signatures" => [
               %{
                 "documentation" => %{
                   "kind" => "markdown",
                   "value" => """
                   Inspects and writes the given `item` to the device.

                   ```
                   @spec inspect(item, keyword) :: item
                   when item: var
                   ```
                   """
                 },
                 "label" => "inspect(item, opts \\\\ [])",
                 "parameters" => [%{"label" => "item"}, %{"label" => "opts \\\\ []"}]
               },
               %{
                 "documentation" => %{
                   "kind" => "markdown",
                   "value" => """
                   Inspects `item` according to the given options using the IO `device`.

                   ```
                   @spec inspect(device, item, keyword) ::
                     item
                   when item: var
                   ```
                   """
                 },
                 "label" => "inspect(device, item, opts)",
                 "parameters" => [
                   %{"label" => "device"},
                   %{"label" => "item"},
                   %{"label" => "opts"}
                 ]
               }
             ]
           }) == resp
  end

  test "reports build diagnostics", %{server: server} do
    in_fixture(__DIR__, "build_errors", fn ->
      error_file = SourceFile.path_to_uri("lib/has_error.ex")

      initialize(server)

      assert_receive notification("textDocument/publishDiagnostics", %{
                       "uri" => ^error_file,
                       "diagnostics" => [
                         %{
                           "message" => "(CompileError) undefined function does_not_exist" <> _,
                           "range" => %{"end" => %{"line" => 3}, "start" => %{"line" => 3}},
                           "severity" => 1
                         }
                       ]
                     }),
                     1000
    end)
  end

  test "reports build diagnostics on external resources", %{server: server} do
    in_fixture(__DIR__, "build_errors_on_external_resource", fn ->
      error_file = SourceFile.path_to_uri("lib/template.eex")

      initialize(server)

      assert_receive notification("textDocument/publishDiagnostics", %{
                       "uri" => ^error_file,
                       "diagnostics" => [
                         %{
                           "message" => "(SyntaxError) syntax error before: ','" <> _,
                           "range" => %{"end" => %{"line" => 1}, "start" => %{"line" => 1}},
                           "severity" => 1
                         }
                       ]
                     }),
                     1000
    end)
  end

  test "reports errors if no mixfile", %{server: server} do
    in_fixture(__DIR__, "no_mixfile", fn ->
      mixfile_uri = SourceFile.path_to_uri("mix.exs")

      initialize(server)

      assert_receive notification("textDocument/publishDiagnostics", %{
                       "uri" => ^mixfile_uri,
                       "diagnostics" => [
                         %{
                           "message" => "No mixfile found" <> _,
                           "severity" => 1
                         }
                       ]
                     }),
                     5000

      assert_receive notification("window/logMessage", %{
                       "message" => "No mixfile found in project." <> _
                     })

      assert_receive notification("window/showMessage", %{
                       "message" => "No mixfile found in project." <> _
                     })
    end)
  end

  test "finds references in non-umbrella project", %{server: server} do
    in_fixture(__DIR__, "references", fn ->
      file_path = "lib/b.ex"
      file_uri = SourceFile.path_to_uri(file_path)
      text = File.read!(file_path)
      reference_uri = SourceFile.path_to_uri("lib/a.ex")

      initialize(server)
      Server.receive_packet(server, did_open(file_uri, "elixir", 1, text))

      Server.receive_packet(
        server,
        references_req(4, file_uri, 1, 8, true)
      )

      resp = assert_receive(%{"id" => 4}, 5000)

      assert response(4, [
               %{
                 "range" => %{"start" => %{"line" => 2}, "end" => %{"line" => 2}},
                 "uri" => ^reference_uri
               }
             ]) = resp
    end)
  end

  test "finds references in umbrella project", %{server: server} do
    in_fixture(__DIR__, "umbrella", fn ->
      file_path = "apps/app2/lib/app2.ex"
      file_uri = SourceFile.path_to_uri(file_path)
      text = File.read!(file_path)
      reference_uri = SourceFile.path_to_uri("apps/app1/lib/app1.ex")

      initialize(server)
      Server.receive_packet(server, did_open(file_uri, "elixir", 1, text))

      Server.receive_packet(
        server,
        references_req(4, file_uri, 1, 9, true)
      )

      resp = assert_receive(%{"id" => 4}, 5000)

      assert response(4, [
               %{
                 "range" => %{"start" => %{"line" => 2}, "end" => %{"line" => 2}},
                 "uri" => ^reference_uri
               }
             ]) = resp
    end)
  end

  @tag :skip_server
  test "loading of umbrella app dependencies" do
    in_fixture(__DIR__, "umbrella", fn ->
      # We test this by opening the umbrella project twice.
      # First to compile the applications and build the cache.
      # Second time to see if loads modules
      with_new_server(fn server ->
        initialize(server)
        wait_until_compiled(server)
      end)

      # unload App2.Foo
      purge([App2.Foo])

      # re-visiting the same project
      with_new_server(fn server ->
        initialize(server)
        wait_until_compiled(server)

        file_path = "apps/app1/lib/bar.ex"
        uri = SourceFile.path_to_uri(file_path)

        code = """
        defmodule Bar do
          def fnuc, do: App2.Fo
          #                    ^
        end
        """

        Server.receive_packet(server, did_open(uri, "elixir", 1, code))
        Server.receive_packet(server, completion_req(3, uri, 1, 23))

        resp = assert_receive(%{"id" => 3}, 5000)

        assert response(3, %{
                 "isIncomplete" => true,
                 "items" => [
                   %{
                     "detail" => "module",
                     "documentation" => _,
                     "kind" => 9,
                     "label" => "Foo"
                   }
                   | _
                 ]
               }) = resp
      end)
    end)
  end

  defp with_new_server(func) do
    server = start_supervised!({Server, nil})
    packet_capture = start_supervised!({PacketCapture, self()})
    Process.group_leader(server, packet_capture)

    try do
      func.(server)
    after
      stop_supervised(Server)
      stop_supervised(PacketCapture)
      flush_mailbox()
    end
  end

  defp flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  defp wait_until_compiled(pid) do
    state = :sys.get_state(pid)

    if state.build_running? do
      Process.sleep(500)
      wait_until_compiled(pid)
    end
  end
end
