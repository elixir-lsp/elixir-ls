if System.otp_release() |> String.to_integer() >= 26 do
  defmodule ElixirLS.LanguageServer.DialyzerIncrementalTest do
    alias ElixirLS.LanguageServer.{
      Server,
      Protocol,
      SourceFile,
      JsonRpc,
      Tracer,
      Build,
      MixProjectCache,
      Parser
    }

    import ElixirLS.LanguageServer.Test.ServerTestHelpers
    use ElixirLS.Utils.MixTest.Case, async: false
    use Protocol

    setup_all do
      compiler_options = Code.compiler_options()
      Build.set_compiler_options()

      on_exit(fn ->
        Code.compiler_options(compiler_options)
      end)

      {:ok, %{}}
    end

    setup do
      {:ok, server} = Server.start_link()
      {:ok, _} = start_supervised(MixProjectCache)
      {:ok, _} = start_supervised(Parser)
      start_server(server)

      {:ok, _tracer} = start_supervised(Tracer)

      on_exit(fn ->
        if Process.alive?(server) do
          Process.monitor(server)
          GenServer.stop(server)

          receive do
            {:DOWN, _, _, ^server, _} ->
              :ok
          end
        else
          :ok
        end
      end)

      {:ok, %{server: server}}
    end

    @tag slow: true, fixture: true
    test "reports diagnostics then clears them once problems are fixed", %{server: server} do
      in_fixture(__DIR__, "dialyzer", fn ->
        file_a = SourceFile.Path.to_uri(Path.absname("lib/a.ex"))

        initialize(server, %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_long"})

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"line" => 1},
                     "start" => %{"line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"line" => 2},
                     "start" => %{"line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function fun/0 has no local return."

        # Make dialyzer error message test more robust across Elixir versions
        error_msg_lower = String.downcase(error_message2)

        assert error_msg_lower =~ "pattern" and error_msg_lower =~ "never match" and
                 error_msg_lower =~ "error"

        # Fix file B. It should recompile and re-analyze A and B only
        b_text = """
        defmodule B do
          def fun do
            :ok
          end
        end
        """

        b_uri = SourceFile.Path.to_uri("lib/b.ex")
        Server.receive_packet(server, did_open(b_uri, "elixir", 1, b_text))
        Process.sleep(1500)
        File.write!("lib/b.ex", b_text)

        Server.receive_packet(server, did_save(b_uri))

        assert_receive publish_diagnostics_notif(^file_a, []), 10000

        assert_receive notification("window/logMessage", %{
                         "message" => "Dialyzer analysis is up to date"
                       }),
                       10000

        wait_until_compiled(server)
      end)
    end

    @tag slow: true, fixture: true
    test "reports dialyxir_long formatted error", %{server: server} do
      in_fixture(__DIR__, "dialyzer", fn ->
        file_a = SourceFile.Path.to_uri(Path.absname("lib/a.ex"))

        initialize(server, %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_long"})

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"line" => 1},
                     "start" => %{"line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"line" => 2},
                     "start" => %{"line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function fun/0 has no local return."

        # Make dialyzer error message test more robust across Elixir versions
        error_msg_lower = String.downcase(error_message2)

        assert error_msg_lower =~ "pattern" and error_msg_lower =~ "never match" and
                 error_msg_lower =~ "error"

        wait_until_compiled(server)
      end)
    end

    @tag slow: true, fixture: true
    test "reports dialyxir_short formatted error", %{server: server} do
      in_fixture(__DIR__, "dialyzer", fn ->
        file_a = SourceFile.Path.to_uri(Path.absname("lib/a.ex"))

        initialize(server, %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_short"})

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"line" => 1},
                     "start" => %{"line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"line" => 2},
                     "start" => %{"line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function fun/0 has no local return."
        # Make dialyzer error message test more robust across Elixir versions
        error_msg_lower = String.downcase(error_message2)

        assert error_msg_lower =~ "pattern" and error_msg_lower =~ "never match" and
                 error_msg_lower =~ "error"

        wait_until_compiled(server)
      end)
    end

    @tag slow: true, fixture: true
    test "reports dialyzer formatted error", %{server: server} do
      in_fixture(__DIR__, "dialyzer", fn ->
        file_a = SourceFile.Path.to_uri(Path.absname("lib/a.ex"))

        initialize(server, %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyzer"})

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"line" => 1},
                     "start" => %{"line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => _error_message2,
                   "range" => %{
                     "end" => %{"line" => 2},
                     "start" => %{"line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function 'fun'/0 has no local return"

        # Note: Don't assert on error_message 2 because the message is not stable across OTP versions
        wait_until_compiled(server)
      end)
    end

    @tag slow: true, fixture: true
    test "reports dialyxir_short error in umbrella", %{server: server} do
      in_fixture(__DIR__, "umbrella_dialyzer", fn ->
        file_a = SourceFile.Path.to_uri(Path.absname("apps/app1/lib/app1.ex"))

        initialize(server, %{"dialyzerEnabled" => true, "dialyzerFormat" => "dialyxir_short"})

        message = assert_receive %{"method" => "textDocument/publishDiagnostics"}, 20000

        assert publish_diagnostics_notif(^file_a, [
                 %{
                   "message" => error_message1,
                   "range" => %{
                     "end" => %{"line" => 1},
                     "start" => %{"line" => 1}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 },
                 %{
                   "message" => error_message2,
                   "range" => %{
                     "end" => %{"line" => 2},
                     "start" => %{"line" => 2}
                   },
                   "severity" => 2,
                   "source" => "ElixirLS Dialyzer"
                 }
               ]) = message

        assert error_message1 == "Function check_error/0 has no local return."
        # Make dialyzer error message test more robust across Elixir versions
        error_msg_lower = String.downcase(error_message2)

        assert error_msg_lower =~ "pattern" and error_msg_lower =~ "never match" and
                 error_msg_lower =~ "error"

        wait_until_compiled(server)
      end)
    end

    test "clears diagnostics when source files are deleted", %{server: server} do
      in_fixture(__DIR__, "dialyzer", fn ->
        file_a = SourceFile.Path.to_uri(Path.absname("lib/a.ex"))

        initialize(server, %{"dialyzerEnabled" => true})

        assert_receive publish_diagnostics_notif(^file_a, [_, _]), 20000

        # Delete file, warning diagnostics should be cleared
        File.rm("lib/a.ex")
        Server.receive_packet(server, did_change_watched_files([%{"uri" => file_a, "type" => 3}]))
        assert_receive publish_diagnostics_notif(^file_a, []), 20000
        wait_until_compiled(server)
      end)
    end

    @tag slow: true, fixture: true
    test "do not suggests contracts if not enabled", %{server: server} do
      in_fixture(__DIR__, "dialyzer", fn ->
        file_c = SourceFile.Path.to_uri(Path.absname("lib/c.ex"))

        initialize(server, %{
          "dialyzerEnabled" => true,
          "dialyzerFormat" => "dialyxir_long",
          "suggestSpecs" => false
        })

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
        wait_until_compiled(server)
      end)
    end

    @tag slow: true, fixture: true
    test "suggests contracts if enabled and applies suggestion", %{server: server} do
      in_fixture(__DIR__, "dialyzer", fn ->
        file_c = SourceFile.Path.to_uri(Path.absname("lib/c.ex"))

        initialize(server, %{
          "dialyzerEnabled" => true,
          "dialyzerFormat" => "dialyxir_long",
          "suggestSpecs" => true
        })

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
                           "spec" => "myfun() :: 1",
                           "uri" => ^file_c
                         }
                       ],
                     "command" => command = "spec:" <> _,
                     "title" => "@spec myfun() :: 1"
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
          "id" => id,
          "method" => "workspace/applyEdit",
          "params" => %{
            "edit" => %{
              "changes" => %{
                ^file_c => [
                  %{
                    "newText" => "  @spec myfun() :: 1\n",
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

        JsonRpc.receive_packet(response(id, %{"applied" => true}))

        assert_receive(%{"id" => 4, "result" => nil}, 5000)
        wait_until_compiled(server)
      end)
    end
  end
end
