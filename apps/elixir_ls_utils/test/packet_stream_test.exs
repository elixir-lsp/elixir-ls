defmodule ElixirLS.Utils.PacketStreamTest do
  use ExUnit.Case, async: true

  alias ElixirLS.Utils.PacketStream

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
end
