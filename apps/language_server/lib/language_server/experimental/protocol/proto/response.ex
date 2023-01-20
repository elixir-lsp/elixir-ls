defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Response do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata

  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.{
    Access,
    Struct,
    Typespec,
    Json,
    Meta
  }

  defmacro defresponse(response_type) do
    CompileMetadata.add_response_module(__CALLER__.module)

    jsonrpc_types = [
      id: quote(do: optional(one_of([integer(), string()]))),
      error: quote(do: optional(LspTypes.ResponseError)),
      result: quote(do: optional(unquote(response_type)))
    ]

    quote location: :keep do
      alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.LspTypes
      unquote(Json.build(__CALLER__.module))
      unquote(Access.build())
      unquote(Struct.build(jsonrpc_types))
      unquote(Typespec.build())
      unquote(Meta.build(jsonrpc_types))

      def new(id, result) do
        struct(__MODULE__, result: result, id: id)
      end

      def error(id, error_code) when is_integer(error_code) do
        %__MODULE__{id: id, error: LspTypes.ResponseError.new(code: error_code)}
      end

      def error(id, error_code) when is_atom(error_code) do
        %__MODULE__{id: id, error: LspTypes.ResponseError.new(code: error_code)}
      end

      def error(id, error_code, error_message)
          when is_integer(error_code) and is_binary(error_message) do
        %__MODULE__{
          id: id,
          error: LspTypes.ResponseError.new(code: error_code, message: error_message)
        }
      end

      def error(id, error_code, error_message)
          when is_atom(error_code) and is_binary(error_message) do
        %__MODULE__{
          id: id,
          error: LspTypes.ResponseError.new(code: error_code, message: error_message)
        }
      end
    end
  end
end
