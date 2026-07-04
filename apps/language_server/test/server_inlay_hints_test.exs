defmodule ElixirLS.LanguageServer.ServerInlayHintsTest do
  @moduledoc """
  Server-level end-to-end tests for `textDocument/inlayHint` (backlog 1.2).

  Coverage:
  A1 — Capability advertisement: initialize response contains inlayHintProvider
       with resolveProvider: false.
  A2 — Full request against an open in-memory document returns a JSON list.
  A3 — Range handling: sub-range request returns a list (possibly shorter).
  A4 — Unicode: document with non-ASCII identifier `café`; request succeeds and
       hint positions are non-negative integers (UTF-16 safe).
  A5 — Cancellation robustness: cancel before response → server stays alive.
  """

  alias ElixirLS.LanguageServer.{Server, Tracer, MixProjectCache, Parser}
  import ElixirLS.LanguageServer.Test.ServerTestHelpers
  use ElixirLS.Utils.MixTest.Case, async: false
  use ElixirLS.LanguageServer.Protocol

  setup context do
    if context[:skip_server] do
      :ok
    else
      {:ok, server} = Server.start_link()
      start_server(server)

      {:ok, _tracer} = start_supervised(Tracer)
      {:ok, _} = start_supervised(MixProjectCache)
      {:ok, _} = start_supervised(Parser)

      on_exit(fn ->
        if Process.alive?(server) do
          Process.monitor(server)
          GenServer.stop(server)

          receive do
            {:DOWN, _, _, ^server, _} -> :ok
          end
        end
      end)

      {:ok, %{server: server}}
    end
  end

  # ── A1: capability advertisement ─────────────────────────────────────────

  describe "initialize — inlayHintProvider capability" do
    test "inlayHintProvider is advertised with resolveProvider: false", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        Server.receive_packet(server, initialize_req(1, root_uri(), %{}))

        assert_receive(
          %{
            "id" => 1,
            "result" => %{
              "capabilities" => %{
                "inlayHintProvider" => %{"resolveProvider" => false}
              }
            }
          },
          3000
        )

        wait_until_compiled(server)
      end)
    end
  end

  # ── A2: full request returns JSON list ───────────────────────────────────

  describe "textDocument/inlayHint — full document request" do
    test "returns a JSON list for a simple Elixir module", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///inlay_test.ex"

        code = """
        defmodule InlayTest do
          def run do
            total = 1 + 2
            total
          end
        end
        """

        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))

        Server.receive_packet(
          server,
          request(1, "textDocument/inlayHint", %{
            "textDocument" => %{"uri" => uri},
            "range" => %{
              "start" => %{"line" => 0, "character" => 0},
              "end" => %{"line" => 10, "character" => 0}
            }
          })
        )

        assert_receive(%{"id" => 1, "result" => result}, 5000)
        assert is_list(result)

        wait_until_compiled(server)
      end)
    end

    test "each hint in the list has a position map", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///inlay_test2.ex"

        code = """
        defmodule InlayTest2 do
          def run do
            total = 1 + 2
            total
          end
        end
        """

        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))

        Server.receive_packet(
          server,
          request(2, "textDocument/inlayHint", %{
            "textDocument" => %{"uri" => uri},
            "range" => %{
              "start" => %{"line" => 0, "character" => 0},
              "end" => %{"line" => 10, "character" => 0}
            }
          })
        )

        assert_receive(%{"id" => 2, "result" => hints}, 5000)
        assert is_list(hints)

        for hint <- hints do
          assert %{"position" => %{"line" => line, "character" => col}} = hint
          assert is_integer(line) and line >= 0
          assert is_integer(col) and col >= 0
        end

        wait_until_compiled(server)
      end)
    end
  end

  # ── A3: range handling ───────────────────────────────────────────────────

  describe "textDocument/inlayHint — sub-range returns list" do
    test "narrow range request returns a list (subset of full hints)", %{server: server} do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///inlay_range.ex"

        code = """
        defmodule InlayRange do
          def run do
            a = 1 + 2
            b = 3 + 4
            {a, b}
          end
        end
        """

        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))

        # Full range
        Server.receive_packet(
          server,
          request(3, "textDocument/inlayHint", %{
            "textDocument" => %{"uri" => uri},
            "range" => %{
              "start" => %{"line" => 0, "character" => 0},
              "end" => %{"line" => 10, "character" => 0}
            }
          })
        )

        assert_receive(%{"id" => 3, "result" => full_hints}, 5000)

        # Narrow range covering only line 2 (the `a = 1 + 2` line)
        Server.receive_packet(
          server,
          request(4, "textDocument/inlayHint", %{
            "textDocument" => %{"uri" => uri},
            "range" => %{
              "start" => %{"line" => 2, "character" => 0},
              "end" => %{"line" => 2, "character" => 99}
            }
          })
        )

        assert_receive(%{"id" => 4, "result" => narrow_hints}, 5000)

        assert is_list(full_hints)
        assert is_list(narrow_hints)
        # Sub-range must not return MORE hints than the full document range.
        assert length(narrow_hints) <= length(full_hints)

        wait_until_compiled(server)
      end)
    end
  end

  # ── A4: Unicode / UTF-16 positions ───────────────────────────────────────

  describe "textDocument/inlayHint — Unicode identifiers (UTF-16 safety)" do
    test "non-ASCII identifier café — request succeeds and positions are valid", %{
      server: server
    } do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///inlay_unicode.ex"

        # `café` is 4 codepoints; in UTF-16 that is still 4 code units (all BMP).
        # The variable binding should produce a hint whose character offset is a
        # non-negative integer — i.e. the server did not crash on multi-byte chars.
        code = """
        defmodule InlayUnicode do
          def run do
            café = String.upcase("café")
            café
          end
        end
        """

        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))

        Server.receive_packet(
          server,
          request(5, "textDocument/inlayHint", %{
            "textDocument" => %{"uri" => uri},
            "range" => %{
              "start" => %{"line" => 0, "character" => 0},
              "end" => %{"line" => 10, "character" => 0}
            }
          })
        )

        assert_receive(%{"id" => 5, "result" => hints}, 5000)
        assert is_list(hints)

        for hint <- hints do
          assert %{"position" => %{"line" => line, "character" => col}} = hint
          # Positions must be non-negative integers (never negative due to bad UTF-16 math).
          assert is_integer(line) and line >= 0
          assert is_integer(col) and col >= 0
        end

        wait_until_compiled(server)
      end)
    end
  end

  # ── A5: cancellation robustness ──────────────────────────────────────────

  describe "textDocument/inlayHint — cancellation" do
    test "cancel before response arrives — server stays alive and responds to next request", %{
      server: server
    } do
      in_fixture(__DIR__, "clean", fn ->
        uri = "file:///inlay_cancel.ex"

        code = """
        defmodule InlayCancel do
          def run do
            total = 1 + 2
            total
          end
        end
        """

        fake_initialize(server)
        Server.receive_packet(server, did_open(uri, "elixir", 1, code))

        # Send inlay hint request then immediately cancel it.
        Server.receive_packet(
          server,
          request(6, "textDocument/inlayHint", %{
            "textDocument" => %{"uri" => uri},
            "range" => %{
              "start" => %{"line" => 0, "character" => 0},
              "end" => %{"line" => 10, "character" => 0}
            }
          })
        )

        Server.receive_packet(server, cancel_request(6))

        # The server must still be alive and able to handle subsequent requests.
        # Send a follow-up request with a new id.
        Server.receive_packet(
          server,
          request(7, "textDocument/inlayHint", %{
            "textDocument" => %{"uri" => uri},
            "range" => %{
              "start" => %{"line" => 0, "character" => 0},
              "end" => %{"line" => 10, "character" => 0}
            }
          })
        )

        assert_receive(%{"id" => 7, "result" => result}, 5000)
        assert is_list(result)

        wait_until_compiled(server)
      end)
    end
  end
end
