defmodule ElixirLS.LanguageServer.MCP.TCPServerTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.MCP.TCPServer

  setup do
    # port: 0 lets the OS assign a free port, so the test does not depend on a
    # particular port being free on the machine running it.
    pid = start_supervised!({TCPServer, port: 0})
    %{listen: :sys.get_state(pid).listen}
  end

  test "binds the listening socket to loopback, not to every interface", %{listen: listen} do
    assert {:ok, {{127, 0, 0, 1}, _port}} = :inet.sockname(listen)
  end
end
