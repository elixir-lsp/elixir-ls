defmodule ElixirLS.LanguageServer.Providers.WorkspaceSymbolsTest do
  use ExUnit.Case, async: false
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols

  setup do
    alias ElixirLS.Utils.PacketCapture
    packet_capture = start_supervised!({PacketCapture, self()})

    {:ok, pid} = WorkspaceSymbols.start_link(name: nil)
    Process.group_leader(pid, packet_capture)

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

    WorkspaceSymbols.notify_build_complete(pid, true)

    wait_until_indexed(pid)

    {:ok, server: pid}
  end

  test "empty query", %{server: server} do
    assert {:ok, []} == WorkspaceSymbols.symbols("", server)

    assert_receive %{
      "method" => "window/logMessage",
      "params" => %{"message" => "[ElixirLS WorkspaceSymbols] Updating index..."}
    }
  end

  test "returns modules", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)

    assert module =
             Enum.find(list, &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"))

    assert module.kind == 2
    assert module.location.uri |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert module.location.range == %{
             end: %{character: 0, line: 1},
             start: %{character: 0, line: 0}
           }

    assert WorkspaceSymbols.symbols("work", server)
           |> elem(1)
           |> Enum.any?(&(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"))
  end

  test "returns functions", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)

    assert some_function =
             Enum.find(
               list,
               &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1")
             )

    assert some_function.kind == 12

    assert some_function.location.uri
           |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert some_function.location.range == %{
             end: %{character: 0, line: 2},
             start: %{character: 0, line: 1}
           }

    assert WorkspaceSymbols.symbols("fun", server)
           |> elem(1)
           |> Enum.any?(
             &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1")
           )
  end

  test "returns types", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)

    assert some_type =
             Enum.find(
               list,
               &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_type/0")
             )

    assert some_type.kind == 5

    assert some_type.location.uri
           |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert some_type.location.range == %{
             end: %{character: 0, line: 8},
             start: %{character: 0, line: 7}
           }

    assert Enum.any?(
             list,
             &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0")
           )

    assert WorkspaceSymbols.symbols("opa", server)
           |> elem(1)
           |> Enum.any?(
             &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0")
           )
  end

  test "returns callbacks", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)

    assert some_callback =
             Enum.find(
               list,
               &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_callback/1")
             )

    assert some_callback.kind == 24

    assert some_callback.location.uri
           |> String.ends_with?("test/support/fixtures/workspace_symbols.ex")

    assert some_callback.location.range == %{
             end: %{character: 0, line: 5},
             start: %{character: 0, line: 4}
           }

    assert Enum.any?(
             list,
             &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1")
           )

    assert WorkspaceSymbols.symbols("macr", server)
           |> elem(1)
           |> Enum.any?(
             &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1")
           )
  end

  defp wait_until_indexed(pid) do
    state = :sys.get_state(pid)

    if state.modules == [] or state.functions == [] or state.types == [] or state.callbacks == [] do
      Process.sleep(500)
      wait_until_indexed(pid)
    end
  end
end
