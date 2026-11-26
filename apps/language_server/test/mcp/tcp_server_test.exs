defmodule ElixirLS.LanguageServer.MCP.TCPServerTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.MCP.TCPServer

  @loopback [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}]

  # port: 0 lets the OS choose a free port, so the tests need no fixed port.
  defp bound_address(opts) do
    pid = start_supervised!({TCPServer, [port: 0] ++ opts})
    {:ok, {ip, _port}} = :inet.sockname(:sys.get_state(pid).listen)
    ip
  end

  test "the default host binds the socket to loopback" do
    assert bound_address([]) in @loopback
  end

  test "the socket binds the host that the supervisor passes" do
    start_supervised!({ElixirLS.LanguageServer.MCP.Supervisor, [port: 0, host: "127.0.0.1"]})
    listen = :sys.get_state(TCPServer).listen
    assert {:ok, {{127, 0, 0, 1}, _port}} = :inet.sockname(listen)
  end

  # 192.0.2.1 is a documentation address, so no machine has it.
  test "a host that cannot be bound does not start the server" do
    assert {:ok, :undefined} = start_supervised({TCPServer, port: 0, host: "192.0.2.1"})
  end

  test "the configured host resolves to the address to bind" do
    assert {:ok, ip} = TCPServer.resolve_host("localhost")
    assert ip in @loopback
    assert TCPServer.resolve_host("127.0.0.1") == {:ok, {127, 0, 0, 1}}
    assert TCPServer.resolve_host("0.0.0.0") == {:ok, {0, 0, 0, 0}}
    assert TCPServer.resolve_host("::1") == {:ok, {0, 0, 0, 0, 0, 0, 0, 1}}
    assert TCPServer.resolve_host("::") == {:ok, {0, 0, 0, 0, 0, 0, 0, 0}}
  end
end
