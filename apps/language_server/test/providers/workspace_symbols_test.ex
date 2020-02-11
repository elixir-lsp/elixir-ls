defmodule ElixirLS.LanguageServer.Providers.DocumentSymbolsTest do
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols
  use ExUnit.Case

  setup_all do
    pid =
      case WorkspaceSymbols.start_link([]) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    state = :sys.get_state(pid)

    fixture_uri =
      ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info(:compile)[:source]
      |> List.to_string()
      |> ElixirLS.LanguageServer.SourceFile.path_to_uri()

    :sys.replace_state(pid, fn _ -> %{state | modified_uris: [fixture_uri]} end)

    WorkspaceSymbols.notify_build_complete()

    wait_until_indexed(pid)

    on_exit(fn ->
      :sys.replace_state(pid, fn _ -> state end)
    end)

    {:ok, %{}}
  end

  test "empty query" do
    assert {:ok, []} == WorkspaceSymbols.symbols("")
  end

  test "returns modules" do
    assert {:ok,
            [
              %{
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
                  uri:
                    "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                },
                name: "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"
              }
            ]} == WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.")

    assert {:ok,
            [
              %{
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
                  uri:
                    "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                },
                name: "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"
              }
            ]} == WorkspaceSymbols.symbols("work")
  end

  test "returns functions" do
    assert {
             :ok,
             [
               %{
                 kind: 12,
                 location: %{
                   range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info/1"
               },
               %{
                 kind: 12,
                 location: %{
                   range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info/0"
               },
               %{
                 kind: 12,
                 location: %{
                   range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.behaviour_info/1"
               },
               %{
                 kind: 12,
                 location: %{
                   range: %{end: %{character: 0, line: 3}, start: %{character: 0, line: 2}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macro/1"
               },
               %{
                 kind: 12,
                 location: %{
                   range: %{end: %{character: 0, line: 2}, start: %{character: 0, line: 1}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1"
               },
               %{
                 kind: 12,
                 location: %{
                   range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.__info__/1"
               }
             ]
           } == WorkspaceSymbols.symbols("f ElixirLS.LanguageServer.Fixtures.")

    assert {:ok,
            [
              %{
                kind: 12,
                location: %{
                  range: %{end: %{character: 0, line: 2}, start: %{character: 0, line: 1}},
                  uri:
                    "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                },
                name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1"
              }
            ]} == WorkspaceSymbols.symbols("f fun")
  end

  test "returns types" do
    assert {
             :ok,
             [
               %{
                 kind: 5,
                 location: %{
                   range: %{end: %{character: 0, line: 8}, start: %{character: 0, line: 7}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "t ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_type/0"
               },
               %{
                 kind: 5,
                 location: %{
                   range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 8}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "t ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0"
               }
             ]
           } == WorkspaceSymbols.symbols("t ElixirLS.LanguageServer.Fixtures.")

    assert {
             :ok,
             [
               %{
                 kind: 5,
                 location: %{
                   range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 8}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "t ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0"
               }
             ]
           } == WorkspaceSymbols.symbols("t opa")
  end

  test "returns callbacks" do
    assert {
             :ok,
             [
               %{
                 kind: 24,
                 location: %{
                   range: %{end: %{character: 0, line: 5}, start: %{character: 0, line: 4}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "c ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_callback/1"
               },
               %{
                 kind: 24,
                 location: %{
                   range: %{end: %{character: 0, line: 6}, start: %{character: 0, line: 5}},
                   uri:
                     "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                 },
                 name: "c ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1"
               }
             ]
           } == WorkspaceSymbols.symbols("c ElixirLS.LanguageServer.Fixtures.")

    assert {:ok,
            [
              %{
                kind: 24,
                location: %{
                  range: %{end: %{character: 0, line: 6}, start: %{character: 0, line: 5}},
                  uri:
                    "file:///Users/lukaszsamson/vscode-elixir-ls/elixir-ls/apps/language_server/test/support/fixtures/workspace_symbols.ex"
                },
                name: "c ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1"
              }
            ]} == WorkspaceSymbols.symbols("c macr")
  end

  defp wait_until_indexed(pid) do
    state = :sys.get_state(pid)

    if state.modules == [] or state.functions == [] or state.types == [] or state.callbacks == [] do
      Process.sleep(500)
      wait_until_indexed(pid)
    end
  end
end
