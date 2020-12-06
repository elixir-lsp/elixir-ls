defmodule ElixirLS.Utils.PacketStreamTest do
  use ExUnit.Case, async: true

  alias ElixirLS.Utils.PacketStream
  import ExUnit.CaptureIO

  describe "content-type" do
    test "default mime" do
      header = %{}
      assert PacketStream.validate_content_type(header) == header
    end

    test "pass error" do
      header = {:error, :some}
      assert PacketStream.validate_content_type(header) == header
    end

    test "default charset" do
      header = %{"Content-Type" => "application/vscode-jsonrpc"}
      assert PacketStream.validate_content_type(header) == header

      header = %{"Content-Type" => "application/VSCode-jsonrpc; key=value"}
      assert PacketStream.validate_content_type(header) == header
    end

    test "supported charset" do
      header = %{"Content-Type" => "application/vscode-jsonrpc; charset=utf-8"}
      assert PacketStream.validate_content_type(header) == header

      header = %{"Content-Type" => "application/vscode-jsonrpc; charset=\"utf-8\""}
      assert PacketStream.validate_content_type(header) == header

      header = %{"Content-Type" => "application/vscode-jsonrpc ; key=value; charset=Utf-8"}
      assert PacketStream.validate_content_type(header) == header

      header = %{"Content-Type" => "application/vscode-jsonrpc;charset=utf8;key=value"}
      assert PacketStream.validate_content_type(header) == header
    end

    test "not supported charset" do
      header = %{"Content-Type" => "application/vscode-jsonrpc; charset=ISO-8859-4"}
      assert PacketStream.validate_content_type(header) == {:error, :not_supported_content_type}
    end

    test "not supported mime" do
      header = %{"Content-Type" => "application/json"}
      assert PacketStream.validate_content_type(header) == {:error, :not_supported_content_type}
    end
  end

  describe "content-length" do
    test "is required" do
      header = %{}
      assert PacketStream.get_content_length(header) == {:error, :invalid_content_length}
    end

    test "valid" do
      header = %{"Content-Length" => "123"}
      assert PacketStream.get_content_length(header) == {:ok, 123}
    end

    test "invalid" do
      header = %{"Content-Length" => "123s"}
      assert PacketStream.get_content_length(header) == {:error, :invalid_content_length}

      header = %{"Content-Length" => "-5"}
      assert PacketStream.get_content_length(header) == {:error, :invalid_content_length}
    end
  end

  describe "read protocol messages" do
    test "valid" do
      {:ok, pid} = File.open("test/fixtures/protocol_messages/valid_message", [:read, :binary])

      [message] =
        PacketStream.stream(pid)
        |> Enum.to_list()

      assert message == %{"some" => "value"}

      File.close(pid)
    end

    test "valid utf" do
      {:ok, pid} =
        File.open("test/fixtures/protocol_messages/valid_message_utf", [:read, :binary])

      [message] =
        PacketStream.stream(pid)
        |> Enum.to_list()

      assert message == %{"some" => "👨‍👩‍👦 test"}

      File.close(pid)
    end

    test "valid with content type" do
      {:ok, pid} = File.open("test/fixtures/protocol_messages/valid_message", [:read, :binary])

      [message] =
        PacketStream.stream(pid)
        |> Enum.to_list()

      assert message == %{"some" => "value"}

      File.close(pid)
    end

    test "valid many" do
      {:ok, pid} = File.open("test/fixtures/protocol_messages/valid_messages", [:read, :binary])

      [message1, message2] =
        PacketStream.stream(pid)
        |> Enum.to_list()

      assert message1 == %{"some" => "value"}
      assert message2 == %{"some" => "value1"}

      File.close(pid)
    end

    test "invalid content length" do
      {:ok, pid} =
        File.open("test/fixtures/protocol_messages/invalid_content_length", [:read, :binary])

      assert capture_io(:stderr, fn ->
               assert [] =
                        PacketStream.stream(pid)
                        |> Enum.to_list()
             end) =~ "Unable to read from device: :truncated"

      File.close(pid)
    end

    test "invalid content type" do
      {:ok, pid} =
        File.open("test/fixtures/protocol_messages/invalid_content_type", [:read, :binary])

      assert capture_io(:stderr, fn ->
               assert [] =
                        PacketStream.stream(pid)
                        |> Enum.to_list()
             end) =~ "Unable to read from device: :not_supported_content_type"

      File.close(pid)
    end

    test "no body" do
      for i <- 0..6 do
        {:ok, pid} = File.open("test/fixtures/protocol_messages/no_body_#{i}", [:read, :binary])

        capture_io(:stderr, fn ->
          assert [] =
                   PacketStream.stream(pid)
                   |> Enum.to_list()
        end)

        File.close(pid)
      end
    end

    test "invalid JSON" do
      {:ok, pid} = File.open("test/fixtures/protocol_messages/invalid_json", [:read, :binary])

      assert capture_io(:stderr, fn ->
               assert [] =
                        PacketStream.stream(pid)
                        |> Enum.to_list()
             end) =~ "Unable to read from device: %JasonVendored.DecodeError"

      File.close(pid)
    end

    test "invalid after valid" do
      {:ok, pid} =
        File.open("test/fixtures/protocol_messages/invalid_after_valid", [:read, :binary])

      assert capture_io(:stderr, fn ->
               # note that we halt the stream and discard any further valid messages
               assert [%{"some" => "value"}] =
                        PacketStream.stream(pid)
                        |> Enum.to_list()
             end) =~ "Unable to read from device: %JasonVendored.DecodeError"

      File.close(pid)
    end
  end
end
