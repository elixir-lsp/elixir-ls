defmodule ElixirLS.LanguageServer.DialyzerTest do
  # TODO: Test loading and saving manifest

  alias ElixirLS.LanguageServer.{Dialyzer, Server, Protocol, SourceFile, JsonRpc, Tracer, Build}
  import ExUnit.CaptureLog
  use ElixirLS.Utils.MixTest.Case, async: false
  use Protocol

  setup_all do
    # This will generate a large PLT file and will take a long time, so we need to make sure that
    # Mix.Utils.home() is in the saved build artifacts for any automated testing
    Dialyzer.Manifest.load_elixir_plt()
    compiler_options = Code.compiler_options()
    Build.set_compiler_options()

    on_exit(fn ->
      Code.compiler_options(compiler_options)
    end)

    {:ok, %{}}
  end

  setup do
    {:ok, _} = Tracer.start_link([])
    server = ElixirLS.LanguageServer.Test.ServerTestHelpers.start_server()

    {:ok, %{server: server}}
  end

  @tag slow: true, fixture: true
  test "reports diagnostics then clears them once problems are fixed", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_a = SourceFile.path_to_uri(Path.absname("lib/a.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_long"}
          })
        )

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"character" => 12, "line" => 1},
                     "start" => %{"character" => 2, "line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"character" => 17, "line" => 2},
                     "start" => %{"character" => 4, "line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function fun/0 has no local return."

        assert error_message2 ==
                 "The pattern can never match the type.\n\nPattern:\n:ok\n\nType:\n:error\n"

        # Fix file B. It should recompile and re-analyze A and B only
        b_text = """
        defmodule B do
          def fun do
            :ok
          end
        end
        """

        b_uri = SourceFile.path_to_uri("lib/b.ex")
        Server.receive_packet(server, did_open(b_uri, "elixir", 1, b_text))
        Process.sleep(1500)
        File.write!("lib/b.ex", b_text)

        Server.receive_packet(server, did_save(b_uri))

        assert_receive publish_diagnostics_notif(^file_a, []), 20000

        assert_receive notification("window/logMessage", %{
                         "message" => "[ElixirLS Dialyzer] Analyzing 2 modules: [A, B]"
                       }),
                       40000

        # Stop while we're still capturing logs to avoid log leakage
        GenServer.stop(server)
      end)
    end)
  end

  @tag slow: true, fixture: true
  test "only analyzes the changed files", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_c = SourceFile.path_to_uri(Path.absname("lib/c.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_long"}
          })
        )

        assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20_000

        c_text = """
        defmodule C do
        end
        """

        c_uri = SourceFile.path_to_uri("lib/c.ex")

        assert_receive notification("window/logMessage", %{
                         "message" => "[ElixirLS Dialyzer] Found " <> _
                       })

        assert_receive notification("window/logMessage", %{
                         "message" => "[ElixirLS Dialyzer] Done writing manifest" <> _
                       }),
                       3_000

        Server.receive_packet(server, did_open(c_uri, "elixir", 1, c_text))

        # The dialyzer process checks a second back since mtime only has second
        # granularity, so we need to wait a second.

        File.write!("lib/c.ex", c_text)
        Process.sleep(1_500)
        Server.receive_packet(server, did_save(c_uri))

        assert_receive notification("window/logMessage", %{
                         "message" => "[ElixirLS Dialyzer] Analyzing 1 modules: [C]"
                       }),
                       3_000

        assert_receive publish_diagnostics_notif(^file_c, []), 20_000

        assert_receive notification("window/logMessage", %{
                         "message" => "[ElixirLS Dialyzer] Done writing manifest" <> _
                       }),
                       3_000

        # Stop while we're still capturing logs to avoid log leakage
        GenServer.stop(server)
      end)
    end)
  end

  @tag slow: true, fixture: true
  test "reports dialyxir_long formatted error", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_a = SourceFile.path_to_uri(Path.absname("lib/a.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_long"}
          })
        )

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"character" => 12, "line" => 1},
                     "start" => %{"character" => 2, "line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"character" => 17, "line" => 2},
                     "start" => %{"character" => 4, "line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function fun/0 has no local return."

        assert error_message2 == """
               The pattern can never match the type.

               Pattern:
               :ok

               Type:
               :error
               """
      end)
    end)
  end

  @tag slow: true, fixture: true
  test "reports dialyxir_short formatted error", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_a = SourceFile.path_to_uri(Path.absname("lib/a.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_short"}
          })
        )

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"character" => 12, "line" => 1},
                     "start" => %{"character" => 2, "line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"character" => 17, "line" => 2},
                     "start" => %{"character" => 4, "line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function fun/0 has no local return."
        assert error_message2 == "The pattern can never match the type :error."
      end)
    end)
  end

  @tag slow: true, fixture: true
  test "reports dialyzer_formatted error", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_a = SourceFile.path_to_uri(Path.absname("lib/a.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyzer"}
          })
        )

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"character" => 12, "line" => 1},
                     "start" => %{"character" => 2, "line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => _error_message2,
                   "range" => %{
                     "end" => %{"character" => 17, "line" => 2},
                     "start" => %{"character" => 4, "line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function 'fun'/0 has no local return"

        # Note: Don't assert on error_messaage 2 because the message is not stable across OTP versions
      end)
    end)
  end

  @tag slow: true, fixture: true
  test "reports dialyxir_short error in umbrella", %{server: server} do
    in_fixture(__DIR__, "umbrella_dialyzer", fn ->
      file_a = SourceFile.path_to_uri(Path.absname("apps/app1/lib/app1.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_short"}
          })
        )

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"character" => 22, "line" => 1},
                     "start" => %{"character" => 2, "line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"character" => 22, "line" => 2},
                     "start" => %{"character" => 4, "line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function check_error/0 has no local return."
        assert error_message2 == "The pattern can never match the type :error."
      end)
    end)
  end

  test "clears diagnostics when source files are deleted", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_a = SourceFile.path_to_uri(Path.absname("lib/a.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{"elixirLS" => %{"dialyzerEnabled" => true}})
        )

        assert_receive publish_diagnostics_notif(^file_a, [_, _]), 20000

        # Delete file, warning diagnostics should be cleared
        File.rm("lib/a.ex")
        Server.receive_packet(server, did_change_watched_files([%{"uri" => file_a, "type" => 3}]))
        assert_receive publish_diagnostics_notif(^file_a, []), 20000

        # Stop while we're still capturing logs to avoid log leakage
        GenServer.stop(server)
      end)
    end)
  end

  @tag slow: true, fixture: true
  test "protocol rebuild does not trigger consolidation warnings", %{server: server} do
    in_fixture(__DIR__, "protocols", fn ->
      root_uri = SourceFile.path_to_uri(File.cwd!())
      uri = SourceFile.path_to_uri(Path.absname("lib/implementations.ex"))

      Server.receive_packet(server, initialize_req(1, root_uri, %{}))
      Server.receive_packet(server, notification("initialized"))

      Server.receive_packet(
        server,
        did_change_configuration(%{"elixirLS" => %{"dialyzerEnabled" => true}})
      )

      assert_receive notification("window/logMessage", %{"message" => "Compile took" <> _}), 5000

      assert_receive notification("window/logMessage", %{
                       "message" => "[ElixirLS Dialyzer] Done writing manifest" <> _
                     }),
                     30000

      v2_text = """
      defimpl Protocols.Example, for: List do
        def some(t), do: t
      end

      defimpl Protocols.Example, for: String do
        def some(t), do: t
      end

      defimpl Protocols.Example, for: Map do
        def some(t), do: t
      end
      """

      Server.receive_packet(server, did_open(uri, "elixir", 1, v2_text))
      File.write!("lib/implementations.ex", v2_text)
      Server.receive_packet(server, did_save(uri))

      assert_receive notification("window/logMessage", %{"message" => "Compile took" <> _}), 5000

      assert_receive notification("textDocument/publishDiagnostics", %{"diagnostics" => []}),
                     30000

      Process.sleep(2000)

      v2_text = """
      defimpl Protocols.Example, for: List do
        def some(t), do: t
      end

      defimpl Protocols.Example, for: String do
        def some(t), do: t
      end

      defimpl Protocols.Example, for: Map do
        def some(t), do: t
      end

      defimpl Protocols.Example, for: Atom do
        def some(t), do: t
      end
      """

      File.write!("lib/implementations.ex", v2_text)
      Server.receive_packet(server, did_save(uri))

      assert_receive notification("window/logMessage", %{"message" => "Compile took" <> _}), 5000

      # we should not receive Protocol has already been consolidated warnings here
      refute_receive notification("textDocument/publishDiagnostics", _), 3000
    end)
  end

  @tag slow: true, fixture: true
  test "do not suggests contracts if not enabled", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_c = SourceFile.path_to_uri(Path.absname("lib/c.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_long"}
          })
        )

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(_, _) = message

        Server.receive_packet(
          server,
          did_open(file_c, "elixir", 2, File.read!(Path.absname("lib/c.ex")))
        )

        Server.receive_packet(
          server,
          code_lens_req(3, file_c)
        )

        resp = assert_receive(%{"id" => 3}, 5000)

        assert response(3, []) == resp
      end)
    end)
  end

  @tag slow: true, fixture: true
  test "suggests contracts if enabled and applies suggestion", %{server: server} do
    in_fixture(__DIR__, "dialyzer", fn ->
      file_c = SourceFile.path_to_uri(Path.absname("lib/c.ex"))

      capture_log(fn ->
        root_uri = SourceFile.path_to_uri(File.cwd!())
        Server.receive_packet(server, initialize_req(1, root_uri, %{}))

        Server.receive_packet(
          server,
          did_change_configuration(%{
            "elixirLS" => %{
              "dialyzerEnabled" => true,
              "dialyzerFormat" => "dialyxir_long",
              "suggestSpecs" => true
            }
          })
        )

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(_, _) = message

        Server.receive_packet(
          server,
          did_open(file_c, "elixir", 2, File.read!(Path.absname("lib/c.ex")))
        )

        Server.receive_packet(
          server,
          code_lens_req(3, file_c)
        )

        resp = assert_receive(%{"id" => 3}, 5000)

        assert response(3, [
                 %{
                   "command" => %{
                     "arguments" =>
                       args = [
                         %{
                           "arity" => 0,
                           "fun" => "myfun",
                           "line" => 2,
                           "mod" => "Elixir.C",
                           "spec" => "myfun :: 1",
                           "uri" => ^file_c
                         }
                       ],
                     "command" => command = "spec:" <> _,
                     "title" => "@spec myfun :: 1"
                   },
                   "range" => %{
                     "end" => %{"character" => 0, "line" => 1},
                     "start" => %{"character" => 0, "line" => 1}
                   }
                 }
               ]) = resp

        Server.receive_packet(
          server,
          execute_command_req(4, command, args)
        )

        assert_receive(%{
          "id" => 1,
          "method" => "workspace/applyEdit",
          "params" => %{
            "edit" => %{
              "changes" => %{
                ^file_c => [
                  %{
                    "newText" => "  @spec myfun :: 1\n",
                    "range" => %{
                      "end" => %{"character" => 0, "line" => 1},
                      "start" => %{"character" => 0, "line" => 1}
                    }
                  }
                ]
              }
            },
            "label" => "Add @spec to Elixir.C.myfun/0"
          }
        })

        # TODO something is broken in packet capture
        # using JsonRpc.receive_packet causes the packet to be delivered to LanguageServer
        # which crashes with no match error
        # JsonRpc.receive_packet(
        #   server,
        #   response(1, %{"applied" => true})
        # )
        # instead we fake a callback in JsonRpc server that forwards the response as needed
        JsonRpc.handle_call(
          {:packet, response(1, %{"applied" => true})},
          nil,
          :sys.get_state(JsonRpc)
        )

        assert_receive(%{"id" => 4, "result" => nil}, 5000)
      end)
    end)
  end
end
