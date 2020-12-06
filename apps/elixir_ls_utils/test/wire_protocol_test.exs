defmodule ElixirLS.Utils.WireProtocolTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias ElixirLS.Utils.WireProtocol

  test "sends valid json" do
    packet = %{"some" => "value"}

    captured =
      capture_io(fn ->
        WireProtocol.send(packet)
      end)

    assert captured == "Content-Length: 16\r\n\r\n{\"some\":\"value\"}"
    "Content-Length: 16\r\n\r\n" <> body = captured
    assert byte_size(body) == 16
    assert JasonVendored.decode!(body) == packet
  end

  test "sends valid json with unicode" do
    File.mkdir_p("test/tmp")
    File.rm_rf!("test/tmp/packet_stream")
    {:ok, pid} = File.open("test/tmp/packet_stream", [:write, :binary])

    packet = %{"some" => "👨‍👩‍👦 test"}

    task =
      Task.async(fn ->
        Process.group_leader(self(), pid)
        WireProtocol.send(packet)
      end)

    Task.await(task)
    File.close(pid)

    bytes = File.read!("test/tmp/packet_stream")
    assert "Content-Length: 34\r\n\r\n" <> body = bytes
    assert byte_size(body) == 34
    assert JasonVendored.decode!(body) == packet
  end
end
