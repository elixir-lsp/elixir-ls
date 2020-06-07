defmodule ElixirLS.LanguageServer.Providers.WorkspaceSymbolsTest do
  use ExUnit.Case, async: false
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols

  @server_name WorkspaceSymbolsTestServer

  setup do
    alias ElixirLS.Utils.PacketCapture
    packet_capture = start_supervised!({PacketCapture, self()})
    Process.register(packet_capture, :elixir_ls_test_process)

    {:ok, pid} = WorkspaceSymbols.start_link(name: @server_name)

    state = :sys.get_state(pid)

    fixture_uri =
      ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info(:compile)[:source]
      |> List.to_string()
      |> ElixirLS.LanguageServer.SourceFile.path_to_uri()

    :sys.replace_state(pid, fn _ ->
      %{
        state
        | modules_indexed: true,
          functions_indexed: true,
          types_indexed: true,
          callbacks_indexed: true,
          modified_uris: [fixture_uri]
      }
    end)

    WorkspaceSymbols.notify_build_complete(@server_name)

    wait_until_indexed(pid)

    {:ok, %{}}
  end

  test "empty query" do
    assert {:ok, []} == WorkspaceSymbols.symbols("", @server_name)

    assert_receive %{
      "method" => "window/logMessage",
      "params" => %{"message" => "[ElixirLS WorkspaceSymbols] Updating index..."}
    }
  end

  test "returns modules" do
    assert {:ok,
            [
              %{
                kind: 2,
                location: %{
                  range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
                  uri: uri
                },
                name: "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"
              }
            ]} =
             WorkspaceSymbols.symbols(
               "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols",
               @server_name
             )

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert {:ok, results} = WorkspaceSymbols.symbols("work", @server_name)

    assert %{
             kind: 2,
             location: %{
               range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
               uri: uri
             },
             name: "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"
           } = matches(results, "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols")

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")
  end

  test "returns functions" do
    query = "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"
    assert {:ok, results} = WorkspaceSymbols.symbols(query, @server_name)

    assert %{
             kind: 12,
             location: %{
               range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}},
               uri: uri
             },
             name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info/1"
           } =
             matches(results, "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info/1")

    assert %{
             kind: 12,
             location: %{
               range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}}
             },
             name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info/0"
           } =
             matches(results, "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.module_info/0")

    assert %{
             kind: 12,
             location: %{
               range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}}
             },
             name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.behaviour_info/1"
           } =
             matches(
               results,
               "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.behaviour_info/1"
             )

    assert %{
             kind: 12,
             location: %{
               range: %{end: %{character: 0, line: 3}, start: %{character: 0, line: 2}}
             },
             name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macro/1"
           } =
             matches(results, "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macro/1")

    assert %{
             kind: 12,
             location: %{
               range: %{end: %{character: 0, line: 2}, start: %{character: 0, line: 1}}
             },
             name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1"
           } =
             matches(
               results,
               "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1"
             )

    assert %{
             kind: 12,
             location: %{
               range: %{end: %{character: 0, line: 1}, start: %{character: 0, line: 0}}
             },
             name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.__info__/1"
           } = matches(results, "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.__info__/1")

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert {:ok,
            [
              %{
                kind: 12,
                location: %{
                  range: %{end: %{character: 0, line: 2}, start: %{character: 0, line: 1}},
                  uri: uri
                },
                name: "f ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1"
              }
            ]} = WorkspaceSymbols.symbols("f some_fun", @server_name)

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")
  end

  test "returns types" do
    assert {
             :ok,
             [
               %{
                 kind: 5,
                 location: %{
                   range: %{end: %{character: 0, line: 8}, start: %{character: 0, line: 7}},
                   uri: uri
                 },
                 name: "t ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_type/0"
               },
               %{
                 kind: 5,
                 location: %{
                   range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 8}}
                 },
                 name: "t ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0"
               }
             ]
           } =
             WorkspaceSymbols.symbols(
               "t ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.",
               @server_name
             )

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert {
             :ok,
             [
               %{
                 kind: 5,
                 location: %{
                   range: %{end: %{character: 0, line: 9}, start: %{character: 0, line: 8}},
                   uri: uri
                 },
                 name: "t ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0"
               }
             ]
           } = WorkspaceSymbols.symbols("t opa", @server_name)

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")
  end

  test "returns callbacks" do
    assert {
             :ok,
             [
               %{
                 kind: 24,
                 location: %{
                   range: %{end: %{character: 0, line: 5}, start: %{character: 0, line: 4}},
                   uri: uri
                 },
                 name: "c ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_callback/1"
               },
               %{
                 kind: 24,
                 location: %{
                   range: %{end: %{character: 0, line: 6}, start: %{character: 0, line: 5}}
                 },
                 name: "c ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1"
               }
             ]
           } =
             WorkspaceSymbols.symbols(
               "c ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.",
               @server_name
             )

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert {:ok,
            [
              %{
                kind: 24,
                location: %{
                  range: %{end: %{character: 0, line: 6}, start: %{character: 0, line: 5}},
                  uri: uri
                },
                name: "c ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1"
              }
            ]} = WorkspaceSymbols.symbols("c macr", @server_name)

    assert uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")
  end

  defp wait_until_indexed(pid) do
    state = :sys.get_state(pid)

    if state.modules == [] or state.functions == [] or state.types == [] or state.callbacks == [] do
      Process.sleep(500)
      wait_until_indexed(pid)
    end
  end

  defp matches(results, name) do
    assert [matching_result] =
             Enum.filter(
               results,
               &(&1.name == name)
             )

    matching_result
  end
end
