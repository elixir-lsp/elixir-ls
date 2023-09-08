defmodule ElixirLS.LanguageServer.ServerTest do
  alias ElixirLS.LanguageServer.{Server, SourceFile, Tracer, Build, JsonRpc}
  alias ElixirLS.Utils.PacketCapture
  alias ElixirLS.LanguageServer.Test.FixtureHelpers
  import ElixirLS.LanguageServer.Test.ServerTestHelpers
  use ElixirLS.Utils.MixTest.Case, async: false
  use ElixirLS.LanguageServer.Protocol

  doctest(Server)

  setup_all do
    on_exit(fn ->
      Code.put_compiler_option(:tracers, [])
    end)
  end

  setup context do
    if context[:skip_server] do
      :ok
    else
      {:ok, server} = Server.start_link()
      start_server(server)
      Process.monitor(server)
      Process.unlink(server)
      {:ok, tracer} = start_supervised(Tracer)

      on_exit(fn ->
        if Process.alive?(server) do
          state = :sys.get_state(server)
          refute state.build_running?

          Process.monitor(server)
          Process.exit(server, :terminate)

          receive do
            {:DOWN, _, _, ^server, _} ->
              :ok
          end
        end
      end)

      {:ok, %{server: server, tracer: tracer}}
    end
  end

  describe "initialize" do
    test "returns error -32002 ServerNotInitialized when not initialized", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "initializes", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        wait_until_compiled(server)
      end)
    end

    test "gets configuration after initialized notification if client supports it", %{
      server: server
    } do
      in_fixture(__DIR__, "clean", fn ->
        Server.receive_packet(
          server,
          initialize_req(1, root_uri(), %{
            "workspace" => %{
              "configuration" => true
            }
          })
        )

        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        Server.receive_packet(server, notification("initialized"))
        uri = root_uri()

        assert_receive(
          %{
            "id" => 1,
            "method" => "workspace/configuration",
            "params" => %{"items" => [%{"scopeUri" => ^uri, "section" => "elixirLS"}]}
          },
          1000
        )

        JsonRpc.receive_packet(
          response(1, [
            %{
              "mixEnv" => "dev",
              "autoBuild" => false,
              "dialyzerEnabled" => false
            }
          ])
        )

        assert :sys.get_state(server).mix_env == "dev"
        wait_until_compiled(server)
      end)
    end

    test "gets configuration after workspace/didChangeConfiguration notification if client supports it",
         %{
           server: server
         } do
      in_fixture(__DIR__, "clean", fn ->
        Server.receive_packet(
          server,
          initialize_req(1, root_uri(), %{
            "workspace" => %{
              "configuration" => true
            }
          })
        )

        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        Server.receive_packet(server, notification("initialized"))
        uri = root_uri()

        assert_receive(
          %{
            "id" => id,
            "method" => "workspace/configuration",
            "params" => %{"items" => [%{"scopeUri" => ^uri, "section" => "elixirLS"}]}
          },
          1000
        )

        config = %{
          "mixEnv" => "dev",
          "autoBuild" => false,
          "dialyzerEnabled" => false
        }

        JsonRpc.receive_packet(response(id, [config]))

        assert_receive(
          %{
            "method" => "window/logMessage",
            "params" => %{
              "message" => "Received client configuration via workspace/configuration" <> _
            }
          },
          1000
        )

        Server.receive_packet(
          server,
          did_change_configuration(nil)
        )

        assert_receive(
          %{
            "id" => id,
            "method" => "workspace/configuration"
          },
          3000
        )

        JsonRpc.receive_packet(response(id, [config]))
        wait_until_compiled(server)
      end)
    end

    test "handles deprecated push based configuration", %{
      server: server
    } do
      in_fixture(__DIR__, "clean", fn ->
        Server.receive_packet(
          server,
          initialize_req(1, root_uri(), %{
            "workspace" => %{
              "configuration" => false
            }
          })
        )

        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        Server.receive_packet(server, notification("initialized"))
        uri = root_uri()

        refute_receive(
          %{
            "id" => 1,
            "method" => "workspace/configuration",
            "params" => %{"items" => [%{"scopeUri" => ^uri, "section" => "elixirLS"}]}
          },
          1000
        )

        config = %{
          "mixEnv" => "dev",
          "autoBuild" => false,
          "dialyzerEnabled" => false
        }

        Server.receive_packet(
          server,
          did_change_configuration(%{"elixirLS" => config})
        )

        assert :sys.get_state(server).mix_env == "dev"
        wait_until_compiled(server)
      end)
    end

    test "falls back do default configuration", %{
      server: server
    } do
      in_fixture(__DIR__, "formatter", fn ->
        :sys.replace_state(server, fn state ->
          %{
            state
            | default_settings: %{
                "dialyzerEnabled" => false
              }
          }
        end)

        Server.receive_packet(
          server,
          initialize_req(1, root_uri(), %{
            "workspace" => %{
              "configuration" => false
            }
          })
        )

        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        Server.receive_packet(server, notification("initialized"))

        assert_receive(
          %{
            "method" => "window/logMessage",
            "params" => %{
              "message" =>
                "Did not receive workspace/didChangeConfiguration notification after 3 seconds. The server will use default config."
            }
          },
          4000
        )

        assert :sys.get_state(server).mix_env == "test"
        wait_until_compiled(server)
      end)
    end

    test "execute commands should include the server instance id", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        # If a command does not include the server instance id then it will cause
        # vscode-elixir-ls to fail to start up on multi-root workspaces.
        # Example: https://github.com/elixir-lsp/elixir-ls/pull/505

        Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
        assert_receive(%{"id" => 1, "result" => result}, 1000)

        commands = get_in(result, ["capabilities", "executeCommandProvider", "commands"])
        server_instance_id = :sys.get_state(server).server_instance_id

        Enum.each(commands, fn command ->
          assert String.contains?(command, server_instance_id)
        end)

        refute Enum.empty?(commands)
        wait_until_compiled(server)
      end)
    end

    test "returns -32600 InvalidRequest when already initialized", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "skips notifications when not initialized", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        code = ~S(
        defmodule MyModule do
          use GenServer
        end
      )

        Server.receive_packet(server, did_open(uri, "elixir", 1, code))
        assert :sys.get_state(server).source_files == %{}
        wait_until_compiled(server)
      end)
    end
  end

  describe "exit" do
    test "exit notifications when not initialized", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        Process.monitor(server)
        wait_until_compiled(server)
        Server.receive_packet(server, notification("exit"))
        assert_receive({:DOWN, _, :process, ^server, {:exit_code, 1}})
      end)
    end

    test "exit notifications after shutdown", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        Process.monitor(server)
        Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        wait_until_compiled(server)
        Server.receive_packet(server, request(2, "shutdown", %{}))
        assert_receive(%{"id" => 2, "result" => nil}, 1000)
        Server.receive_packet(server, notification("exit"))
        assert_receive({:DOWN, _, :process, ^server, {:exit_code, 0}})
      end)
    end

    test "returns -32600 InvalidRequest when shutting down", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        wait_until_compiled(server)
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
      end)
    end

    test "skips notifications when not shutting down", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        Server.receive_packet(server, initialize_req(1, root_uri(), %{}))
        assert_receive(%{"id" => 1, "result" => %{"capabilities" => %{}}}, 1000)
        wait_until_compiled(server)
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
      end)
    end
  end

  describe "not matched messages" do
    test "not supported $/ notifications are skipped", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        fake_initialize(server)
        Server.receive_packet(server, notification("$/not_supported"))
        :sys.get_state(server)
        refute_receive(%{"method" => "window/logMessage"})
        wait_until_compiled(server)
      end)
    end

    test "not matched notifications log warning", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        fake_initialize(server)
        Server.receive_packet(server, notification("not_matched"))
        :sys.get_state(server)

        assert_receive(%{
          "method" => "window/logMessage",
          "params" => %{"message" => "Received unmatched notification" <> _, "type" => 2}
        })

        wait_until_compiled(server)
      end)
    end

    test "not supported $/ requests return -32601 MethodNotFound", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        wait_until_compiled(server)
      end)
    end

    test "not matched requests return -32600 InvalidRequest and log warning", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "not matched executeCommand requests return -32600 InvalidRequest and log warning", %{
      server: server
    } do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end
  end

  describe "text synchronization" do
    test "textDocument/didOpen", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "textDocument/didOpen already open", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "textDocument/didClose", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        wait_until_compiled(server)
      end)
    end

    test "textDocument/didClose not open", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "textDocument/didChange", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        wait_until_compiled(server)
      end)
    end

    test "textDocument/didChange not open", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        wait_until_compiled(server)
      end)
    end

    test "textDocument/didSave", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    test "textDocument/didSave not open", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        wait_until_compiled(server)
      end)
    end
  end

  describe "workspace/didChangeWatchedFiles" do
    test "not watched file changed outside", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "watched file created outside", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    test "watched file updated outside", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 2}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    test "watched file deleted outside", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 3}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    test "watched open file created in editor", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
        wait_until_compiled(server)
      end)
    end

    # this case compiles 2 times but cannot be easily fixed without breaking other cases
    test "watched open file created in editor, didSave sent", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, did_save(uri))
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

        state = :sys.get_state(server)
        assert state.needs_build?
        assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
        wait_until_compiled(server)
      end)
    end

    test "watched open file saved in editor", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, did_save(uri))
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 2}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
        wait_until_compiled(server)
      end)
    end

    test "watched open file deleted in editor", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, did_close(uri))
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 3}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    @tag :fixture
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
        uri = SourceFile.Path.to_uri("lib/a.ex")
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))
        Server.receive_packet(server, did_change(uri, 1, content_changes))
        state = :sys.get_state(server)
        %SourceFile{text: updated_code} = Server.get_source_file(state, uri)
        File.write!("lib/a.ex", updated_code)
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        assert %SourceFile{dirty?: false} = Server.get_source_file(state, uri)
        wait_until_compiled(server)
      end)
    end

    @tag :fixture
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
        uri = SourceFile.Path.to_uri("lib/a.ex")
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))
        Server.receive_packet(server, did_change(uri, 1, content_changes))
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 1}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        assert %SourceFile{dirty?: true} = Server.get_source_file(state, uri)
        wait_until_compiled(server)
      end)
    end

    test "watched open file created outside, read error", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        assert state.needs_build? || state.build_running?
        assert %SourceFile{dirty?: true} = Server.get_source_file(state, uri)

        assert_receive %{
                         "method" => "window/logMessage",
                         "params" => %{"message" => "Unable to read file" <> _, "type" => 2}
                       },
                       1000

        wait_until_compiled(server)
      end)
    end

    test "watched open file updated outside, read error", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    test "watched open file deleted outside", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.ex"
        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 3}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    # https://github.com/elixir-lsp/elixir-ls/pull/569
    @tag :additional_extension
    test "watched file updated outside, non-default extension", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///file.veex"
        fake_initialize(server)

        # Simulate settings related to this test
        :sys.replace_state(server, fn state ->
          %{state | settings: %{"additionalWatchedExtensions" => [".veex"]}}
        end)

        # Check if *.veex file triggers build
        Server.receive_packet(server, did_change_watched_files([%{"uri" => uri, "type" => 2}]))

        state = :sys.get_state(server)
        assert state.needs_build? || state.build_running?
        wait_until_compiled(server)
      end)
    end

    test "gracefully skip not supported URI scheme", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "git://github.com/user/repo.git"
        fake_initialize(server)

        Server.receive_packet(
          server,
          did_change_watched_files([%{"uri" => uri, "type" => 2}])
        )

        wait_until_compiled(server)
      end)
    end
  end

  test "hover", %{server: server} do
    in_fixture(__DIR__, "clean", fn ->
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

      wait_until_compiled(server)
    end)
  end

  test "auto complete", %{server: server} do
    in_fixture(__DIR__, "clean", fn ->
      uri = "file:///file.ex"
      code = ~S(
    defmodule MyModule do
      def my_fn, do: GenSer
    end
    )
      fake_initialize(server)
      Server.receive_packet(server, did_open(uri, "elixir", 1, code))
      Server.receive_packet(server, completion_req(1, uri, 2, 25))

      resp = assert_receive(%{"id" => 1}, 10000)

      assert response(1, %{
               "isIncomplete" => true,
               "items" => [
                 %{
                   "detail" => "behaviour",
                   "documentation" => _,
                   "kind" => 8,
                   "label" => "GenServer"
                 }
                 | _
               ]
             }) = resp

      wait_until_compiled(server)
    end)
  end

  describe "textDocument/definition" do
    test "definition found", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
          |> SourceFile.Path.to_uri()

        assert_receive(
          response(1, %{
            "range" => %{
              "end" => %{"character" => 0, "line" => 0},
              "start" => %{"character" => 0, "line" => 0}
            },
            "uri" => ^uri
          }),
          3000
        )

        wait_until_compiled(server)
      end)
    end

    test "definition not found", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        fake_initialize(server)
        uri = "file:///file.ex"
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, definition_req(1, uri, 0, 43))

        assert_receive(
          response(1, nil),
          3000
        )

        wait_until_compiled(server)
      end)
    end
  end

  describe "textDocument/implementation" do
    test "implementations found", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        file_path = FixtureHelpers.get_path("example_behaviour.ex")
        text = File.read!(file_path)
        uri = SourceFile.Path.to_uri(file_path)
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

        wait_until_compiled(server)
      end)
    end

    test "implementations not found", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        fake_initialize(server)
        uri = "file:///file.ex"
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, implementation_req(1, uri, 0, 43))

        assert_receive(
          response(1, []),
          15000
        )

        wait_until_compiled(server)
      end)
    end
  end

  describe "requests cancellation" do
    test "known request", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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

        wait_until_compiled(server)
      end)
    end

    test "unknown request", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
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
        wait_until_compiled(server)
      end)
    end
  end

  describe "requests shutdown" do
    test "without params", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        fake_initialize(server)
        wait_until_compiled(server)
        Server.receive_packet(server, request(1, "shutdown"))
        assert %{received_shutdown?: true} = :sys.get_state(server)
      end)
    end

    test "with params", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        fake_initialize(server)
        wait_until_compiled(server)
        Server.receive_packet(server, request(1, "shutdown", nil))
        assert %{received_shutdown?: true} = :sys.get_state(server)
      end)
    end
  end

  test "uri request when the source file is not open returns -32602",
       %{server: server} do
    in_fixture(__DIR__, "clean", fn ->
      fake_initialize(server)

      Server.receive_packet(server, document_symbol_req(1, "file:///file.ex"))

      assert_receive(
        %{
          "id" => 1,
          "error" => %{"code" => -32602, "message" => "invalid URI: \"file:///file.ex\""}
        },
        1000
      )

      wait_until_compiled(server)
    end)
  end

  test "uri async request when the source file is not open returns -32602",
       %{server: server} do
    in_fixture(__DIR__, "clean", fn ->
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

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "incremental formatter", %{server: server} do
    in_fixture(__DIR__, "formatter", fn ->
      uri = Path.join([root_uri(), "file.ex"])

      uri
      |> SourceFile.Path.absolute_from_uri()
      |> File.write!("")

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
      wait_until_compiled(server)
    end)
  end

  test "signature help", %{server: server} do
    in_fixture(__DIR__, "clean", fn ->
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
                     "value" =>
                       """
                       Inspects and writes the given `item` to the device.

                       ```
                       @spec inspect\
                       """ <> _
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
             }) = resp

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "reports build diagnostics", %{server: server} do
    in_fixture(__DIR__, "build_errors", fn ->
      error_file = SourceFile.Path.to_uri("lib/has_error.ex")

      initialize(server)

      if Version.match?(System.version(), ">= 1.15.0") do
        assert_receive notification("textDocument/publishDiagnostics", %{
                         "uri" => ^error_file,
                         "diagnostics" => [
                           %{
                             "message" =>
                               "(CompileError) lib/has_error.ex: cannot compile module" <> _,
                             "range" => %{"end" => %{"line" => 0}, "start" => %{"line" => 0}},
                             "severity" => 1
                           },
                           %{
                             "message" => "undefined function does_not_exist/0" <> _,
                             "range" => %{
                               "end" => %{"character" => 20, "line" => 3},
                               "start" => %{"character" => 4, "line" => 3}
                             },
                             "severity" => 1,
                             "source" => "Elixir"
                           }
                         ]
                       }),
                       1000
      else
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
      end

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "reports token missing error diagnostics", %{server: server} do
    in_fixture(__DIR__, "token_missing_error", fn ->
      error_file = SourceFile.Path.to_uri("lib/has_error.ex")

      initialize(server)

      assert_receive notification("textDocument/publishDiagnostics", %{
                       "uri" => ^error_file,
                       "diagnostics" => [
                         %{
                           "message" => "(TokenMissingError) missing terminator: end" <> _,
                           "range" => %{"end" => %{"line" => 5}, "start" => %{"line" => 5}},
                           "severity" => 1
                         }
                       ]
                     }),
                     1000

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "reports build diagnostics on external resources", %{server: server} do
    in_fixture(__DIR__, "build_errors_on_external_resource", fn ->
      error_file = SourceFile.Path.to_uri("lib/template.eex")

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
                     2000

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "finds references in non-umbrella project", %{server: server} do
    in_fixture(__DIR__, "references", fn ->
      file_path = "lib/b.ex"
      file_uri = SourceFile.Path.to_uri(file_path)
      text = File.read!(file_path)
      reference_uri = SourceFile.Path.to_uri("lib/a.ex")

      Build.set_compiler_options()

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

      wait_until_compiled(server)
    end)
  after
    Code.put_compiler_option(:tracers, [])
  end

  @tag :fixture
  test "finds references in umbrella project", %{server: server} do
    in_fixture(__DIR__, "umbrella", fn ->
      file_path = "apps/app2/lib/app2.ex"
      file_uri = SourceFile.Path.to_uri(file_path)
      text = File.read!(file_path)
      reference_uri = SourceFile.Path.to_uri("apps/app1/lib/app1.ex")

      Build.set_compiler_options()

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

      wait_until_compiled(server)
    end)
  after
    Code.put_compiler_option(:tracers, [])
  end

  @tag fixture: true, skip_server: true
  test "loading of umbrella app dependencies" do
    in_fixture(__DIR__, "umbrella", fn ->
      packet_capture = start_supervised!({PacketCapture, self()})
      replace_logger(packet_capture)
      # We test this by opening the umbrella project twice.
      # First to compile the applications and build the cache.
      # Second time to see if loads modules
      with_new_server(packet_capture, fn server ->
        {:ok, _pid} = Tracer.start_link([])
        initialize(server)
      end)

      # unload App2.Foo
      purge([App2.Foo])

      # re-visiting the same project
      with_new_server(packet_capture, fn server ->
        initialize(server)

        file_path = "apps/app1/lib/bar.ex"
        uri = SourceFile.Path.to_uri(file_path)

        code = """
        defmodule Bar do
          def fnuc, do: App2.Fo
          #                    ^
        end
        """

        Server.receive_packet(server, did_open(uri, "elixir", 1, code))
        Server.receive_packet(server, completion_req(3, uri, 1, 23))

        resp = assert_receive(%{"id" => 3}, 10000)

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

  @tag :fixture
  test "returns code lenses for runnable tests", %{server: server} do
    in_fixture(__DIR__, "test_code_lens", fn ->
      file_path = "test/fixture_test.exs"
      file_uri = SourceFile.Path.to_uri(file_path)
      # this is not an abs path as returned by Path.absname
      # on Windows it's c:\asdf instead of c:/asdf
      file_absolute_path = SourceFile.Path.from_uri(file_uri)
      text = File.read!(file_path)

      project_dir = SourceFile.Path.absolute_from_uri(root_uri())

      initialize(server, %{"enableTestLenses" => true, "dialyzerEnabled" => false})

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
                       "testName" => "fixture test",
                       "projectDir" => ^project_dir
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
                       "module" => "Elixir.TestCodeLensTest",
                       "projectDir" => ^project_dir
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

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "returns code lenses for runnable tests in umbrella apps",
       %{
         server: server
       } do
    in_fixture(__DIR__, "umbrella_test_code_lens", fn ->
      file_path = "apps/app1/test/fixture_custom_test.exs"
      file_uri = SourceFile.Path.to_uri(file_path)
      file_absolute_path = SourceFile.Path.from_uri(file_uri)
      text = File.read!(file_path)
      project_dir = SourceFile.Path.absolute_from_uri("#{root_uri()}/apps/app1")

      initialize(server, %{"enableTestLenses" => true, "dialyzerEnabled" => false})

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
                       "testName" => "fixture test",
                       "projectDir" => ^project_dir
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
                       "module" => "Elixir.App1.UmbrellaTestCodeLensTest",
                       "projectDir" => ^project_dir
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

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "does not return code lenses for runnable tests when test lenses settings is not set", %{
    server: server
  } do
    in_fixture(__DIR__, "test_code_lens", fn ->
      file_path = "test/fixture_test.exs"
      file_uri = SourceFile.Path.to_uri(file_path)
      text = File.read!(file_path)

      fake_initialize(server)

      Server.receive_packet(server, did_open(file_uri, "elixir", 1, text))

      Server.receive_packet(
        server,
        code_lens_req(4, file_uri)
      )

      resp = assert_receive(%{"id" => 4}, 5000)

      assert response(4, []) = resp
      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "returns code lenses for runnable tests with custom test paths and test pattern", %{
    server: server
  } do
    in_fixture(__DIR__, "test_code_lens_custom_paths_and_pattern", fn ->
      file_path = "custom_path/fixture_custom_test.exs"
      file_uri = SourceFile.Path.to_uri(file_path)
      file_absolute_path = SourceFile.Path.from_uri(file_uri)
      text = File.read!(file_path)
      project_dir = SourceFile.Path.absolute_from_uri(root_uri())

      initialize(server, %{"enableTestLenses" => true, "dialyzerEnabled" => false})

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
                       "testName" => "fixture test",
                       "projectDir" => ^project_dir
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
                       "module" => "Elixir.TestCodeLensCustomPathsAndPatternTest",
                       "projectDir" => ^project_dir
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

      wait_until_compiled(server)
    end)
  end

  @tag :fixture
  test "returns code lenses for runnable tests with custom test paths and test pattern in umbrella apps",
       %{
         server: server
       } do
    in_fixture(__DIR__, "umbrella_test_code_lens_custom_path_and_pattern", fn ->
      file_path = "apps/app1/custom_path/fixture_custom_test.exs"
      file_uri = SourceFile.Path.to_uri(file_path)
      file_absolute_path = SourceFile.Path.from_uri(file_uri)
      text = File.read!(file_path)
      project_dir = SourceFile.Path.absolute_from_uri("#{root_uri()}/apps/app1")

      initialize(server, %{
        "enableTestLenses" => true,
        "testPaths" => %{"app1" => ["custom_path"]},
        "testPattern" => %{"app1" => "*_custom_test.exs"},
        "dialyzerEnabled" => false
      })

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
                       "testName" => "fixture test",
                       "projectDir" => ^project_dir
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
                       "module" => "Elixir.UmbrellaTestCodeLensCustomPathAndPatternTest",
                       "projectDir" => ^project_dir
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

      wait_until_compiled(server)
    end)
  end

  describe "no mix project" do
    @tag :fixture
    test "dir with no mix.exs", %{server: server} do
      in_fixture(__DIR__, "no_mixfile", fn ->
        initialize(server)

        assert_receive notification("window/logMessage", %{
                         "message" => "No mixfile found in project." <> _
                       }),
                       1000

        assert_receive notification("window/showMessage", %{
                         "message" => "No mixfile found in project." <> _
                       })

        assert_receive notification("window/logMessage", %{
                         "message" => "Compile took" <> _
                       })

        uri = SourceFile.Path.to_uri("a.ex")
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, did_save(uri))

        assert_receive notification("window/logMessage", %{
                         "message" => "Compile took" <> _
                       })

        wait_until_compiled(server)
      end)
    end

    @tag :fixture
    test "single file", %{server: server} do
      in_fixture(__DIR__, "no_mixfile", fn ->
        Server.receive_packet(server, initialize_req(1, nil, %{}))
        Server.receive_packet(server, notification("initialized"))

        Server.receive_packet(
          server,
          did_change_configuration(%{"elixirLS" => %{"dialyzerEnabled" => false}})
        )

        refute_receive notification("window/logMessage", %{
                         "message" => "No mixfile found in project." <> _
                       }),
                       1000

        wait_until_compiled(server)
        uri = SourceFile.Path.to_uri("a.ex")
        Server.receive_packet(server, did_open(uri, "elixir", 1, ""))
        Server.receive_packet(server, did_save(uri))

        assert_receive notification("textDocument/publishDiagnostics", %{
                         "diagnostics" => [],
                         "uri" => ^uri
                       })

        wait_until_compiled(server)
      end)
    end
  end

  defp with_new_server(packet_capture, func) do
    server = start_supervised!({Server, nil})

    Process.group_leader(server, packet_capture)

    json_rpc = start_supervised!({JsonRpc, name: JsonRpc})
    Process.group_leader(json_rpc, packet_capture)

    try do
      func.(server)
    after
      wait_until_compiled(server)
      stop_supervised(Server)
      stop_supervised(JsonRpc)
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
end
