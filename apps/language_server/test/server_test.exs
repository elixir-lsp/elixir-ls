defmodule ElixirLS.LanguageServer.ServerTest do
  alias ElixirLS.LanguageServer.{Server, Protocol, SourceFile}
  alias ElixirLS.Utils.PacketCapture
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
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

  defp fake_initialize(server) do
    :sys.replace_state(server, fn state -> %{state | server_instance_id: "123"} end)
  end

  defp root_uri do
    SourceFile.path_to_uri(File.cwd!())
  end

  describe "initialize" do
    test "returns error -32002 ServerNotInitialized when not initialized", %{server: server} do
      uri = "file:///file.ex"
      Server.receive_packet(server, completion_req(1, uri, 2, 25))

      assert_receive(
        %{
          "id" => 1,
          "error" => %{
            "code" => -32002
          }
        },
        1000
      )
    end

    test "initializes", %{server: server} do
      Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
      assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
    end

    test "returns -32600 InvalidRequest when already initialized", %{server: server} do
      Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
      assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
      Server.receive_packet(server, initialize_req(1, root_uri(), %{}))

      assert_receive(
        %{
          "id" => 1,
          "error" => %{
            "code" => -32600
          }
        },
        1000
      )
    end

    test "skips notifications when not initialized", %{server: server} do
      uri = "file:///file.ex"
      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )

      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      assert :sys.get_state(server).source_files == %{}
    end
  end

  describe "exit" do
    test "exit notifications when not initialized", %{server: server} do
      Process.monitor(server)
      Server.receive_packet(server, notification("exit"))
      assert_receive({:DOWN, _, :process, ^server, {:exit_code, 1}})
    end

    test "exit notifications after shutdown", %{server: server} do
      Process.monitor(server)
      Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
      assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
      Server.receive_packet(server, request(2, "shutdown", %{}))
      assert_receive(%{"id" => 2, "result" => nil}, 1000)
      Server.receive_packet(server, notification("exit"))
      assert_receive({:DOWN, _, :process, ^server, {:exit_code, 0}})
    end

    test "returns -32600 InvalidRequest when shutting down", %{server: server} do
      Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
      assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
      Server.receive_packet(server, request(2, "shutdown", %{}))
      assert_receive(%{"id" => 2, "result" => nil}, 1000)

      Server.receive_packet(server, hover_req(1, "file:///file.ex", 2, 17))

      assert_receive(
        %{
          "id" => 1,
          "error" => %{
            "code" => -32600
          }
        },
        1000
      )
    end

    test "skips notifications when not shutting down", %{server: server} do
      Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
      assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
      Server.receive_packet(server, request(2, "shutdown", %{}))
      assert_receive(%{"id" => 2, "result" => nil}, 1000)

      uri = "file:///file.ex"
      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )

      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      assert :sys.get_state(server).source_files == %{}
    end
  end

  describe "not matched messages" do
    test "not supported $/ notifications are skipped", %{server: server} do
      fake_initialize(server)
      Server.receive_packet(server, notification("$/not_supported"))
      :sys.get_state(server)
      refute_receive(%{"method" => "window/logMessage"})
    end

    test "not matched notifications log warning", %{server: server} do
      fake_initialize(server)
      Server.receive_packet(server, notification("not_matched"))
      :sys.get_state(server)

      assert_receive(%{
        "method" => "window/logMessage",
        "params" => %{"message" => "Received unmatched notification" <> _, "type" => 2}
      })
    end

    test "not supported $/ requests return -32601 MethodNotFound", %{server: server} do
      fake_initialize(server)
      Server.receive_packet(server, request(1, "$/not_supported"))

      assert_receive(
        %{
          "id" => 1,
          "error" => %{
            "code" => -32601
          }
        },
        1000
      )

      refute_receive(%{"method" => "window/logMessage"})
    end

    test "not matched requests return -32600 InvalidRequest and log warning", %{server: server} do
      fake_initialize(server)
      Server.receive_packet(server, request(1, "not_matched"))

      assert_receive(
        %{
          "id" => 1,
          "error" => %{
            "code" => -32600
          }
        },
        1000
      )

      assert_receive(%{
        "method" => "window/logMessage",
        "params" => %{"message" => "Unmatched request" <> _, "type" => 2}
      })
    end

    test "not matched executeCommand requests return -32600 InvalidRequest and log warning", %{
      server: server
    } do
      fake_initialize(server)
      Server.receive_packet(server, execute_command_req(1, "not_matched", ["a", "bc"]))

      assert_receive(
        %{
          "id" => 1,
          "error" => %{
            "code" => -32600
          }
        },
        1000
      )

      assert_receive(%{
        "method" => "window/logMessage",
        "params" => %{"message" => "Unmatched request" <> _, "type" => 2}
      })
    end
  end

  setup context do
    unless context[:skip_server] do
      server = ElixirLS.LanguageServer.Test.ServerTestHelpers.start_server()

      {:ok, %{server: server}}
    else
      :ok
    end
  end

  describe "text synchronization" do
    test "textDocument/didOpen", %{server: server} do
      uri = "file:///file.ex"
      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))

      state = :sys.get_state(server)

      assert %SourceFile{dirty?: false, text: ^code, version: 1} =
               Server.get_source_file(state, uri)

      assert_receive notification("textDocument/publishDiagnostics", %{
                       "uri" => ^uri,
                       "diagnostics" => []
                     }),
                     1000
    end

    test "textDocument/didOpen already open", %{server: server} do
      uri = "file:///file.ex"
      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{
                         "message" =>
                           "Received textDocument/didOpen for file that is already open" <> _,
                         "type" => 2
                       }
                     },
                     1000
    end

    test "textDocument/didClose", %{server: server} do
      uri = "file:///file.ex"
      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, did_close(uri))

      state = :sys.get_state(server)
      assert_raise Server.InvalidParamError, fn -> Server.get_source_file(state, uri) end
    end

    test "textDocument/didClose not open", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_close(uri))

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{
                         "message" =>
                           "Received textDocument/didClose for file that is not open" <> _,
                         "type" => 2
                       }
                     },
                     1000
    end

    test "textDocument/didChange", %{server: server} do
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

      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, did_change(uri, 1, content_changes))

      state = :sys.get_state(server)
      assert %SourceFile{dirty?: true, version: 2} = Server.get_source_file(state, uri)
    end

    test "textDocument/didChange not open", %{server: server} do
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

      fake_initialize(server)
      Server.receive_packet(server, did_change(uri, 1, content_changes))

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{
                         "message" =>
                           "Received textDocument/didChange for file that is not open" <> _,
                         "type" => 2
                       }
                     },
                     1000

      state = :sys.get_state(server)
      refute Map.has_key?(state.source_files, uri)
    end

    test "textDocument/didSave", %{server: server} do
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

      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, did_change(uri, 1, content_changes))
      Server.receive_packet(server, did_save(uri))

      state = :sys.get_state(server)
      assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
      assert state.needs_build?
    end

    test "textDocument/didSave not open", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_save(uri))

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{
                         "message" =>
                           "Received textDocument/didSave for file that is not open" <> _,
                         "type" => 2
                       }
                     },
                     1000

      state = :sys.get_state(server)
      refute Map.has_key?(state.source_files, uri)
    end
  end

  describe "workspace/didChangeWatchedFiles" do
    test "not watched file changed outside", %{server: server} do
      uri = "file:///file.txt"
      fake_initialize(server)

      for change_type <- 1..3 do
        Server.receive_packet(
          server,
          did_change_watched_files([%{"uri" => uri, "type" => change_type}])
        )

        state = :sys.get_state(server)
        refute state.needs_build?
      end
    end

    test "watched file created outside", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

      state = :sys.get_state(server)
      assert state.needs_build?
    end

    test "watched file updated outside", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 2}]))

      state = :sys.get_state(server)
      assert state.needs_build?
    end

    test "watched file deleted outside", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 3}]))

      state = :sys.get_state(server)
      assert state.needs_build?
    end

    test "watched open file created in editor", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

      state = :sys.get_state(server)
      assert state.needs_build?
      assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
    end

    # this case compiles 2 times but cannot be easily fixed without breaking other cases
    test "watched open file created in editor, didSave sent", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, did_save(uri))
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

      state = :sys.get_state(server)
      assert state.needs_build?
      assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
    end

    test "watched open file saved in editor", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, did_save(uri))
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 2}]))

      state = :sys.get_state(server)
      assert state.needs_build?
      assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
    end

    test "watched open file deleted in editor", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, did_close(uri))
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 3}]))

      state = :sys.get_state(server)
      assert state.needs_build?
    end

    test "watched open file created outside, contents same", %{server: server} do
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

      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )

      in_fixture(__DIR__, "references", fn ->
        uri = SourceFile.path_to_uri("lib/a.ex")
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))
        Server.receive_packet(server, did_change(uri, 1, content_changes))
        state = :sys.get_state(server)
        %SourceFile{text: updated_code} = Server.get_source_file(state, uri)
        File.write!("lib/a.ex", updated_code)
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

        state = :sys.get_state(server)
        assert state.needs_build?
        assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
      end)
    end

    test "watched open file created outside, contents differ", %{server: server} do
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

      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )

      in_fixture(__DIR__, "references", fn ->
        uri = SourceFile.path_to_uri("lib/a.ex")
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))
        Server.receive_packet(server, did_change(uri, 1, content_changes))
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

        state = :sys.get_state(server)
        assert state.needs_build?
        assert %SourceFile{dirty?: true} = Server.get_source_file(state, uri)
      end)
    end

    test "watched open file created outside, read error", %{server: server} do
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

      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, did_change(uri, 1, content_changes))
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

      state = :sys.get_state(server)
      assert state.needs_build?
      assert %SourceFile{dirty?: true} = Server.get_source_file(state, uri)

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{"message" => "Unable to read file" <> _, "type" => 2}
                     },
                     1000
    end

    test "watched open file updated outside, read error", %{server: server} do
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

      code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, did_change(uri, 1, content_changes))
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 2}]))

      state = :sys.get_state(server)
      assert %SourceFile{dirty?: true} = Server.get_source_file(state, uri)
      assert state.needs_build?
    end

    test "watched open file deleted outside", %{server: server} do
      uri = "file:///file.ex"
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 3}]))

      state = :sys.get_state(server)
      assert state.needs_build?
    end
  end

  test "hover", %{server: server} do
    uri = "file:///file.ex"
    code = ~S(
      defmodule MyModule do
        use GenServer
      end
    )
    fake_initialize(server)
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
    fake_initialize(server)
    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, completion_req(1, uri, 2, 25))

    resp = assert_receive(%{"id" => 1}, 1000)

    assert response(1, %{
             "isIncomplete" => true,
             "items" => [
               %{
                 "detail" => "behaviour",
                 "documentation" => _,
                 "kind" => 8,
                 "label" => "GenServer (behaviour)"
               }
               | _
             ]
           }) = resp
  end

  describe "textDocument/definition" do
    test "definition found", %{server: server} do
      uri = "file:///file.ex"
      code = ~S(
        defmodule MyModule do
          @behaviour ElixirLS.LanguageServer.Fixtures.ExampleBehaviour
        end
      )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, definition_req(1, uri, 2, 58))

      uri =
        ElixirLS.LanguageServer.Fixtures.ExampleBehaviour.module_info()[:compile][:source]
        |> to_string
        |> SourceFile.path_to_uri()

      assert_receive(
        response(1, %{
          "range" => %{
            "end" => %{"character" => column, "line" => 0},
            "start" => %{"character" => column, "line" => 0}
          },
          "uri" => ^uri
        }),
        3000
      )

      assert column > 0
    end

    test "definition not found", %{server: server} do
      fake_initialize(server)
      uri = "file:///file.ex"
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, definition_req(1, uri, 0, 43))

      assert_receive(
        response(1, nil),
        3000
      )
    end
  end

  describe "textDocument/implementation" do
    test "implementations found", %{server: server} do
      file_path = FixtureHelpers.get_path("example_behaviour.ex")
      text = File.read!(file_path)
      uri = SourceFile.path_to_uri(file_path)
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, text))

      # force load as currently only loaded or loadable modules that are a part
      # of an application are found
      Code.ensure_loaded?(ElixirLS.LanguageServer.Fixtures.ExampleBehaviourImpl)

      Server.receive_packet(server, implementation_req(1, uri, 0, 43))

      assert_receive(
        response(1, [
          %{
            "range" => %{
              "end" => %{"character" => _, "line" => _},
              "start" => %{"character" => _, "line" => _}
            },
            "uri" => ^uri
          }
        ]),
        15000
      )
    end

    test "implementations not found", %{server: server} do
      fake_initialize(server)
      uri = "file:///file.ex"
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, implementation_req(1, uri, 0, 43))

      assert_receive(
        response(1, []),
        15000
      )
    end
  end

  describe "requests cancellation" do
    test "known request", %{server: server} do
      fake_initialize(server)
      uri = "file:///file.ex"
      Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
      Server.receive_packet(server, hover_req(1, uri, 1, 1))
      Server.receive_packet(server, cancel_request(1))

      state = :sys.get_state(server)
      refute Map.has_key?(state.requests, 1)

      assert_receive %{
        "error" => %{"code" => -32800, "message" => "Request cancelled"},
        "id" => 1,
        "jsonrpc" => "2.0"
      }
    end

    test "unknown request", %{server: server} do
      fake_initialize(server)
      Process.monitor(server)
      Server.receive_packet(server, cancel_request(1))

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{
                         "message" => "Received $/cancelRequest for unknown request" <> _,
                         "type" => 2
                       }
                     },
                     1000

      refute_receive {:DOWN, _, _, _, _}
    end
  end

  describe "requests shutdown" do
    test "without params", %{server: server} do
      fake_initialize(server)
      Server.receive_packet(server, request(1, "shutdown"))
      assert %{received_shutdown?: true} = :sys.get_state(server)
    end

    test "with params", %{server: server} do
      fake_initialize(server)
      Server.receive_packet(server, request(1, "shutdown", nil))
      assert %{received_shutdown?: true} = :sys.get_state(server)
    end
  end

  test "uri request when the source file is not open returns -32602",
       %{server: server} do
    fake_initialize(server)

    Server.receive_packet(server, document_symbol_req(1, "file:///file.ex"))

    assert_receive(
      %{
        "id" => 1,
        "error" => %{"code" => -32602, "message" => "invalid URI: \"file:///file.ex\""}
      },
      1000
    )
  end

  test "uri async request when the source file is not open returns -32602",
       %{server: server} do
    fake_initialize(server)

    Server.receive_packet(
      server,
      execute_command_req(1, "spec:1", [
        %{
          "uri" => "file:///file.ex",
          "mod" => "Mod",
          "fun" => "fun",
          "arity" => 1,
          "spec" => "",
          "line" => 1
        }
      ])
    )

    assert_receive(
      %{
        "id" => 1,
        "error" => %{"code" => -32602, "message" => "invalid URI: \"file:///file.ex\""}
      },
      1000
    )
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
    fake_initialize(server)
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

  test "returns code lenses for runnable tests", %{server: server} do
    in_fixture(__DIR__, "test_code_lens", fn ->
      file_path = "test/fixture_test.exs"
      file_uri = SourceFile.path_to_uri(file_path)
      file_absolute_path = SourceFile.path_from_uri(file_uri)
      text = File.read!(file_path)

      fake_initialize(server)

      Server.receive_packet(
        server,
        did_change_configuration(%{"elixirLS" => %{"enableTestLenses" => true}})
      )

      Server.receive_packet(server, did_open(file_uri, "elixir", 1, text))

      Server.receive_packet(
        server,
        code_lens_req(4, file_uri)
      )

      resp = assert_receive(%{"id" => 4}, 5000)

      assert response(4, [
               %{
                 "command" => %{
                   "arguments" => [
                     %{
                       "filePath" => ^file_absolute_path,
                       "testName" => "fixture test"
                     }
                   ],
                   "command" => "elixir.lens.test.run",
                   "title" => "Run test"
                 },
                 "range" => %{
                   "end" => %{"character" => 0, "line" => 3},
                   "start" => %{"character" => 0, "line" => 3}
                 }
               },
               %{
                 "command" => %{
                   "arguments" => [
                     %{
                       "filePath" => ^file_absolute_path,
                       "module" => "Elixir.TestCodeLensTest"
                     }
                   ],
                   "command" => "elixir.lens.test.run",
                   "title" => "Run tests in module"
                 },
                 "range" => %{
                   "end" => %{"character" => 0, "line" => 0},
                   "start" => %{"character" => 0, "line" => 0}
                 }
               }
             ]) = resp
    end)
  end

  test "does not return code lenses for runnable tests when test lenses settings is not set", %{
    server: server
  } do
    in_fixture(__DIR__, "test_code_lens", fn ->
      file_path = "test/fixture_test.exs"
      file_uri = SourceFile.path_to_uri(file_path)
      text = File.read!(file_path)

      fake_initialize(server)

      Server.receive_packet(server, did_open(file_uri, "elixir", 1, text))

      Server.receive_packet(
        server,
        code_lens_req(4, file_uri)
      )

      resp = assert_receive(%{"id" => 4}, 5000)

      assert response(4, []) = resp
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
