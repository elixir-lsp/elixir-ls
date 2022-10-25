defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.LspTypes do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  use Proto

  defmodule ErrorCodes do
    use Proto

    defenum parse_error: -32700,
            invalid_request: -32600,
            method_not_found: -32601,
            invalid_params: -32602,
            internal_error: -32603,
            server_not_initialized: -32002,
            unknown_error_code: -32001,
            request_failed: -32803,
            server_cancelled: -32802,
            content_modified: -32801,
            request_cancelled: -32800
  end

  defmodule ResponseError do
    use Proto
    deftype code: ErrorCodes, message: string(), data: optional(any())
  end
end
