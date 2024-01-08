defmodule ElixirLS.LanguageServer.Providers.WorkspaceSymbolsTest do
  alias ElixirLS.LanguageServer.Providers.WorkspaceSymbols
  alias ElixirLS.LanguageServer.{Server, Protocol, Tracer, MixProjectCache}
  use ElixirLS.Utils.MixTest.Case, async: false
  import ElixirLS.LanguageServer.Test.ServerTestHelpers
  use Protocol

  setup do
    {:ok, _} = start_supervised(Tracer)
    {:ok, server} = Server.start_link()
    {:ok, _} = start_supervised(MixProjectCache)
    # {:ok, pid} = start_supervised({WorkspaceSymbols, name: nil})
    start_server(server)
    :persistent_term.put(:language_server_override_test_mode, true)

    on_exit(fn ->
      :persistent_term.put(:language_server_override_test_mode, false)

      if Process.alive?(server) do
        Process.monitor(server)
        GenServer.stop(server)

        receive do
          {:DOWN, _, _, ^server, _} ->
            :ok
        end
      end
    end)

    {:ok, %{server: server}}
  end

  test "empty query", %{server: server} do
    in_fixture(Path.join(__DIR__, ".."), "workspace_symbols", fn ->
      initialize(server)

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{"message" => "Compile took" <> _}
                     },
                     20000

      assert {:ok, list} = WorkspaceSymbols.symbols("")
      assert is_list(list)
      assert list != []
    end)
  end

  test "returns modules", %{server: server} do
    in_fixture(Path.join(__DIR__, ".."), "workspace_symbols", fn ->
      initialize(server)

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{"message" => "Compile took" <> _}
                     },
                     20000

      assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.")

      assert module =
               Enum.find(list, &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"))

      assert module.kind == 11
      assert module.location.uri |> String.ends_with?("lib/workspace_symbols.ex")

      assert module.location.range == %{
               end: %{character: 0, line: 1},
               start: %{character: 0, line: 0}
             }

      assert WorkspaceSymbols.symbols("work")
             |> elem(1)
             |> Enum.any?(&(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"))
    end)
  end

  test "returns functions", %{server: server} do
    in_fixture(Path.join(__DIR__, ".."), "workspace_symbols", fn ->
      initialize(server)

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{"message" => "Compile took" <> _}
                     },
                     20000

      assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.")

      assert some_function =
               Enum.find(
                 list,
                 &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1")
               )

      assert some_function.kind == 12

      assert some_function.containerName == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"

      assert some_function.location.uri
             |> String.ends_with?("lib/workspace_symbols.ex")

      assert some_function.location.range == %{
               end: %{character: 0, line: 2},
               start: %{character: 0, line: 1}
             }

      assert WorkspaceSymbols.symbols("fun")
             |> elem(1)
             |> Enum.any?(
               &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_function/1")
             )
    end)
  end

  test "returns types", %{server: server} do
    in_fixture(Path.join(__DIR__, ".."), "workspace_symbols", fn ->
      initialize(server)

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{"message" => "Compile took" <> _}
                     },
                     20000

      assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.")

      assert some_type =
               Enum.find(
                 list,
                 &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_type/0")
               )

      assert some_type.kind == 5

      assert some_type.containerName == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"

      assert some_type.location.uri
             |> String.ends_with?("lib/workspace_symbols.ex")

      assert some_type.location.range == %{
               end: %{character: 0, line: 8},
               start: %{character: 0, line: 7}
             }

      assert Enum.any?(
               list,
               &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0")
             )

      assert WorkspaceSymbols.symbols("opa")
             |> elem(1)
             |> Enum.any?(
               &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_opaque_type/0")
             )
    end)
  end

  test "returns callbacks", %{server: server} do
    in_fixture(Path.join(__DIR__, ".."), "workspace_symbols", fn ->
      initialize(server)

      assert_receive %{
                       "method" => "window/logMessage",
                       "params" => %{"message" => "Compile took" <> _}
                     },
                     20000

      assert {:ok, list} = WorkspaceSymbols.symbols("ElixirLS.LanguageServer.Fixtures.")

      assert some_callback =
               Enum.find(
                 list,
                 &(&1.name == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_callback/1")
               )

      assert some_callback.kind == 24

      assert some_callback.containerName == "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols"

      assert some_callback.location.uri
             |> String.ends_with?("lib/workspace_symbols.ex")

      assert some_callback.location.range == %{
               end: %{character: 0, line: 5},
               start: %{character: 0, line: 4}
             }

      assert Enum.any?(
               list,
               &(&1.name ==
                   "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1")
             )

      assert WorkspaceSymbols.symbols("macr")
             |> elem(1)
             |> Enum.any?(
               &(&1.name ==
                   "ElixirLS.LanguageServer.Fixtures.WorkspaceSymbols.some_macrocallback/1")
             )
    end)
  end
end
