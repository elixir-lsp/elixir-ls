defmodule ElixirLS.LanguageServer.ServerTest do
  alias ElixirLS.LanguageServer.{Builder, Server, Protocol}
  alias ElixirLS.IOHandler.PacketCapture
  use ExUnit.Case, async: false
  use Protocol

  doctest Server

  setup do
    {:ok, server} = Server.start_link
    {:ok, packet_capture} = PacketCapture.start_link(self())
    Process.group_leader(server, packet_capture)

    # Remove build output between tests
    Builder.clean(Path.expand("fixtures/build_errors"))
    File.rm_rf!(Path.expand("fixtures/build_errors/.elixir_ls", __DIR__))

    {:ok, %{server: server}}
  end

  test "hover", %{server: server} do
    uri = "file:///file.ex"
    code = ~S(
      defmodule MyModule do
        use GenServer
      end
    )
    
    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, hover_req(1, uri, 2, 17))

    assert_receive response(1, %{"contents" => "> GenServer" <> _, 
        "range" => %{"start" => %{"line" => 2, "character" => 12}, 
          "end" => %{"line" => 2, "character" => 21}}})
  end

  test "auto complete", %{server: server} do
    uri = "file:///file.ex"
    code = ~S(
      defmodule MyModule do
        use Gen
      end
    )
    
    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, completion_req(1, uri, 2, 16))

    assert_receive response(1, %{
        "isIncomplete" => true,
        "items" => [
          %{"detail" => "module",
            "documentation" => "A behaviour module for implementing event handling functionality.",
            "kind" => 9, "label" => "GenEvent",
            "sortText" => "1_0_GenEvent"},
          %{"detail" => "module",
            "documentation" => 
              "A behaviour module for implementing the server of a client-server relation.",
            "kind" => 9, "label" => "GenServer",
            "sortText" => "1_0_GenServer"}]})
  end

  test "go to definition", %{server: server} do 
    uri = "file:///file.ex"
    code = ~S(
      defmodule MyModule do
        use GenServer
      end
    )
    
    Server.receive_packet(server, did_open(uri, "elixir", 1, code))
    Server.receive_packet(server, definition_req(1, uri, 2, 17))

    uri = "file://" <> to_string(GenServer.module_info[:compile][:source])
    assert_receive response(1, %{
          "range" => %{"end" => %{"character" => 0, "line" => 0}, 
            "start" => %{"character" => 0, "line" => 0}},
          "uri" => ^uri})
  end

  test "requests cancellation", %{server: server} do
    Server.receive_packet(server, hover_req(1, "file:///file.ex", 1, 1))
    Server.receive_packet(server, cancel_request(1))

    assert_receive %{
      "error" => %{"code" => -32800, "message" => "Request cancelled"},
      "id" => 1, "jsonrpc" => "2.0"
    }
  end

  test "responses are sent in order of request regardless of completion order", %{server: server} do
    for id <- 1..3, do: Server.receive_packet(server, hover_req(id, "file:///file.ex", 1, 1))
    for id <- 3..1, do: Server.receive_packet(server, cancel_request(id))

    for id <- 1..3 do
      receive do
        message -> assert %{"id" => ^id, "error" => %{"code" => -32800}} = message
      end
    end
  end

  test "opening project generates build warnings and errors", %{server: server} do
    root_uri = "file://" <> Path.expand("fixtures/build_errors", __DIR__)
    warning_file = root_uri <> "/lib/has_warning.ex"
    error_file = root_uri <> "/lib/has_error.ex"

    Server.receive_packet(server, initialize_req(1, root_uri, %{}))

    assert_receive notification("textDocument/publishDiagnostics", %{
        "uri" => ^error_file,
        "diagnostics" => [%{"message" => "undefined function does_not_exist/0", 
            "range" => %{"start" => %{"character" => 0, "line" => 4}, 
              "end" => %{"character" => 0, "line" => 4}},
            "severity" => 1}]
    })

    assert_receive notification("textDocument/publishDiagnostics", %{
        "uri" => ^warning_file,
        "diagnostics" => [%{"message" => "variable \"unused\" is unused", 
            "range" => %{"start" => %{"character" => 0, "line" => 3}, 
              "end" => %{"character" => 0, "line" => 3}},
            "severity" => 2}]
    })
  end

  test "opening a file updates build errors with more precise range", %{server: server} do

    root_uri = "file://" <> Path.expand("fixtures/build_errors", __DIR__)
    warning_file = root_uri <> "/lib/has_warning.ex"

    Server.receive_packet(server, initialize_req(1, root_uri, %{}))
    Server.receive_packet(server, did_open(
      root_uri <> "/lib/has_warning.ex", "elixir", 1, 
      File.read!(String.trim_leading(warning_file, "file://"))
    ))

    assert_receive notification("textDocument/publishDiagnostics", %{
        "uri" => ^warning_file,
        "diagnostics" => [%{"message" => "variable \"unused\" is unused", 
            "range" => %{"start" => %{"character" => 12, "line" => 3}, 
              "end" => %{"character" => 18, "line" => 3}},
            "severity" => 2}]
    })
  end

  test "changing open files triggers rebuild", %{server: server} do
    root_uri = "file://" <> Path.expand("fixtures/build_errors", __DIR__)
    warning_file = root_uri <> "/lib/has_warning.ex"

    Server.receive_packet(server, initialize_req(1, root_uri, %{}))
    Server.receive_packet(server, did_open(
      root_uri <> "/lib/has_warning.ex", "elixir", 1, 
      File.read!(String.trim_leading(warning_file, "file://"))
    ))

    changed_text = ~S/defmodule MyModule do
      def my_fn(changed), do: :ok
    end/

    Server.receive_packet(server, did_change(
        warning_file, 2, [%{"text" => changed_text}]))
    assert_receive notification("textDocument/publishDiagnostics", 
      %{"uri" => ^warning_file,
        "diagnostics" => [%{
            "message" => "variable \"changed\" is unused",
            "range" => %{"end" => %{"character" => 23, "line" => 1},
              "start" => %{"character" => 16, "line" => 1}},
            "severity" => 2}]})
  end

end