defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Request do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata

  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.{
    Access,
    Struct,
    Parse,
    Typespec,
    Meta
  }

  defmacro defrequest(method, types) do
    alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.TypeFunctions
    import TypeFunctions, only: [optional: 1, integer: 0, literal: 1]

    CompileMetadata.add_request_module(__CALLER__.module)

    # id is optional so we can resuse the parse function. If it's required,
    # it will go in the pattern match for the params, which won't work.

    jsonrpc_types = [
      id: quote(do: optional(integer())),
      jsonrpc: quote(do: literal("2.0")),
      method: quote(do: literal(unquote(method)))
    ]

    all_types = Keyword.merge(jsonrpc_types, types)

    quote location: :keep do
      unquote(Access.build())
      unquote(Struct.build(all_types))
      unquote(Typespec.build())
      unquote(build_request_parse_function(method))
      unquote(Parse.build(types))
      unquote(Meta.build(all_types))

      def __meta__(:method_name) do
        unquote(method)
      end

      def __meta__(:type) do
        :request
      end

      def __meta__(:param_names) do
        unquote(Keyword.keys(types))
      end
    end
  end

  defp build_request_parse_function(method) do
    quote do
      def parse(%{"method" => unquote(method), "id" => id, "jsonrpc" => "2.0"} = request) do
        params = Map.get(request, "params", %{})

        case parse(params) do
          {:ok, request} ->
            request =
              request
              |> Map.put(:id, id)
              |> Map.put(:method, unquote(method))
              |> Map.put(:jsonrpc, "2.0")

            {:ok, request}

          error ->
            error
        end
      end
    end
  end
end
