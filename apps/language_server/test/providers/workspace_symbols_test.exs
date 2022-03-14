defmodule ElixirLS.LanguageServer.Providers.WorkspaceSymbolsTest do
  use ExUnit.Case, async: false
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols

  setup do
    alias ElixirLS.Utils.PacketCapture
    packet_capture = start_supervised!({PacketCapture, self()})

    {:ok, pid} =
      WorkspaceSymbols.start_link(
        name: nil,
        args: [paths: ["test/support/fixtures/workspace_symbols"]]
      )

    Process.group_leader(pid, packet_capture)

    wait_until_indexed(pid)

    {:ok, server: pid}
  end

  test "empty query returns all symbols", %{server: server} do
    expected_symbols = [
      "def some_function(a)",
      "defmacro some_macro(a)",
      "some_callback(integer)",
      "some_macrocallback(integer)",
      "some_type",
      "some_opaque_type",
      "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"
    ]

    assert {:ok, list} = WorkspaceSymbols.symbols("", server)

    assert length(list) == 7

    for symbol <- list do
      assert symbol.name in expected_symbols
    end
  end

  test "returns modules", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)

    assert module =
             Enum.find(list, &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"))

    assert module.kind == 2

    assert String.ends_with?(module.location.uri, "test/support/fixtures/workspace_symbols/workspace_symbols.ex")

    assert module.location.range == %{
             "end" => %{"character" => 0, "line" => 0},
             "start" => %{"character" => 0, "line" => 0}
           }

    assert WorkspaceSymbols.symbols("work", server)
           |> elem(1)
           |> Enum.any?(&(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"))
  end

  test "returns functions", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)

    assert some_function = Enum.find(list, &(&1.name == "def some_function(a)"))

    assert some_function.kind == 12

    assert String.ends_with?(
             some_function.location.uri,
             "test/support/fixtures/workspace_symbols/workspace_symbols.ex"
           )

    assert some_function.location.range == %{
             "end" => %{"character" => 6, "line" => 1},
             "start" => %{"character" => 6, "line" => 1}
           }

    assert WorkspaceSymbols.symbols("fun", server)
           |> elem(1)
           |> Enum.any?(&(&1.name == "def some_function(a)"))
  end

  test "returns types", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)
    assert some_type = Enum.find(list, &(&1.name == "some_type"))
    assert some_type.kind == 5

    assert String.ends_with?(
             some_type.location.uri,
             "test/support/fixtures/workspace_symbols/workspace_symbols.ex"
           )

    assert some_type.location.range == %{
             "end" => %{"character" => 3, "line" => 7},
             "start" => %{"character" => 3, "line" => 7}
           }

    assert Enum.any?(list, &(&1.name == "some_opaque_type"))

    assert WorkspaceSymbols.symbols("opa", server)
           |> elem(1)
           |> Enum.any?(&(&1.name == "some_opaque_type"))
  end

  test "returns callbacks", %{server: server} do
    assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.", server)
    assert some_callback = Enum.find(list, &(&1.name == "some_callback(integer)"))
    assert some_callback.kind == 24

    assert String.ends_with?(
             some_callback.location.uri,
             "test/support/fixtures/workspace_symbols/workspace_symbols.ex"
           )

    assert some_callback.location.range == %{
             "end" => %{"character" => 3, "line" => 4},
             "start" => %{"character" => 3, "line" => 4}
           }

    assert Enum.any?(list, &(&1.name == "some_macrocallback(integer)"))

    assert WorkspaceSymbols.symbols("macr", server)
           |> elem(1)
           |> Enum.any?(&(&1.name == "some_macrocallback(integer)"))
  end

  defp wait_until_indexed(pid) do
    state = :sys.get_state(pid)

    if Enum.empty?(state.symbols) do
      Process.sleep(500)
      wait_until_indexed(pid)
    end
  end
end
