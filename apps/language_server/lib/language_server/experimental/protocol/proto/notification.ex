defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Notification do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata

  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.{
    Access,
    Meta,
    Parse,
    Struct,
    Typespec
  }

  defmacro defnotification(method, types) do
    CompileMetadata.add_notification_module(__CALLER__.module)

    jsonrpc_types = [
      jsonrpc: quote(do: literal("2.0")),
      method: quote(do: literal(unquote(method)))
    ]

    all_types = Keyword.merge(jsonrpc_types, types)

    quote location: :keep do
      unquote(Access.build())
      unquote(Struct.build(all_types))
      unquote(Typespec.build())
      unquote(build_notification_parse_function(method))
      unquote(Parse.build(types))
      unquote(Meta.build(all_types))

      def __meta__(:method_name) do
        unquote(method)
      end

      def __meta__(:type) do
        :notification
      end

      def __meta__(:param_names) do
        unquote(Keyword.keys(types))
      end
    end
  end

  defp build_notification_parse_function(method) do
    quote do
      def parse(%{"method" => unquote(method), "jsonrpc" => "2.0"} = request) do
        params = Map.get(request, "params", %{})

        case parse(params) do
          {:ok, result} ->
            result =
              result
              |> Map.put(:method, unquote(method))
              |> Map.put(:jsonrpc, "2.0")

            {:ok, result}

          error ->
            error
        end
      end
    end
  end
end
