# codegen: do not edit
defmodule GenLSP.Enumerations.LSPErrorCodes do
  @type t :: -32803 | -32802 | -32801 | -32800

  import SchematicV, warn: false

  @doc """
  A request failed but it was syntactically correct, e.g the
  method name was known and the parameters were valid. The error
  message should contain human readable information about why
  the request failed.

  @since 3.17.0
  """
  @spec request_failed() :: -32803
  def request_failed, do: -32803

  @doc """
  The server cancelled the request. This error code should
  only be used for requests that explicitly support being
  server cancellable.

  @since 3.17.0
  """
  @spec server_cancelled() :: -32802
  def server_cancelled, do: -32802

  @doc """
  The server detected that the content of a document got
  modified outside normal conditions. A server should
  NOT send this error code if it detects a content change
  in it unprocessed messages. The result even computed
  on an older state might still be useful for the client.

  If a client decides that a result is not of any use anymore
  the client should cancel the request.
  """
  @spec content_modified() :: -32801
  def content_modified, do: -32801

  @doc """
  The client has canceled a request and a server as detected
  the cancel.
  """
  @spec request_cancelled() :: -32800
  def request_cancelled, do: -32800

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    oneof([
      -32803,
      -32802,
      -32801,
      -32800,
      int()
    ])
  end
end
