# codegen: do not edit
defmodule GenLSP.Enumerations.ErrorCodes do
  @moduledoc """
  Predefined error codes.
  """

  @type t :: -32700 | -32600 | -32601 | -32602 | -32603 | -32002 | -32001

  import SchematicV, warn: false

  @spec parse_error() :: -32700
  def parse_error, do: -32700

  @spec invalid_request() :: -32600
  def invalid_request, do: -32600

  @spec method_not_found() :: -32601
  def method_not_found, do: -32601

  @spec invalid_params() :: -32602
  def invalid_params, do: -32602

  @spec internal_error() :: -32603
  def internal_error, do: -32603

  @doc """
  Error code indicating that a server received a notification or
  request before the server has received the `initialize` request.
  """
  @spec server_not_initialized() :: -32002
  def server_not_initialized, do: -32002

  @spec unknown_error_code() :: -32001
  def unknown_error_code, do: -32001

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      -32700,
      -32600,
      -32601,
      -32602,
      -32603,
      -32002,
      -32001,
      int()
    ])
  end
end
