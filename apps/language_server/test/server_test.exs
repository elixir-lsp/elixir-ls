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

  setup do
    {:ok, server} = Server.start_link()
    {:ok, packet_capture} = PacketCapture.start_link(self())
    Process.group_leader(server, packet_capture)

    {:ok, %{server: server}}
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
             "contents" => "> GenServer" <> _,
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
             "isIncomplete" => false,
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
                 "documentation" => "@spec inspect(item, keyword) :: item when item: var\n" <> _,
                 "label" => "inspect(item, opts \\\\ [])",
                 "parameters" => [%{"label" => "item"}, %{"label" => "opts \\\\ []"}]
               },
               %{
                 "documentation" =>
                   "@spec inspect(device, item, keyword) :: item when item: var\n" <> _,
                 "label" => "inspect(device, item, opts)",
                 "parameters" => [
                   %{"label" => "device"},
                   %{"label" => "item"},
                   %{"label" => "opts"}
                 ]
               }
             ]
           }) = resp
  end

  test "reports build diagnostics", %{server: server} do
    in_fixture(__DIR__, "build_errors", fn ->
      error_file = SourceFile.path_to_uri("lib/has_error.ex")

      initialize(server)

      assert_receive notification("textDocument/publishDiagnostics", %{
                       "uri" => ^error_file,
                       "diagnostics" => [
                         %{
                           "message" =>
                             "** (CompileError) lib/has_error.ex:4: undefined function does_not_exist" <>
                               _,
                           "range" => %{"end" => %{"line" => 3}, "start" => %{"line" => 3}},
                           "severity" => 1
                         }
                       ]
                     })
    end)
  end

  test "reports error if no mixfile", %{server: server} do
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
end
