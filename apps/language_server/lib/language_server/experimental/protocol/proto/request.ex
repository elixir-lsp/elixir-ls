defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Request do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Message
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.TypeFunctions

  import TypeFunctions, only: [optional: 1, integer: 0, literal: 1]

  defmacro defrequest(method, types) do
    CompileMetadata.add_request_module(__CALLER__.module)
    # id is optional so we can resuse the parse function. If it's required,
    # it will go in the pattern match for the params, which won't work.

    jsonrpc_types = [
      id: quote(do: optional(integer())),
      jsonrpc: quote(do: literal("2.0")),
      method: quote(do: literal(unquote(method)))
    ]

    lsp_types = Keyword.merge(jsonrpc_types, types)
    elixir_types = Message.generate_elixir_types(__CALLER__.module, lsp_types)
    param_names = Keyword.keys(types)

    quote location: :keep do
      defmodule LSP do
        unquote(Message.build({:request, :lsp}, method, lsp_types, param_names))
      end

      alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Convert
      alias ElixirLS.LanguageServer.Experimental.Protocol.Types

      unquote(
        Message.build({:request, :elixir}, method, elixir_types, param_names,
          include_parse?: false
        )
      )

      unquote(build_parse(method))

      def new(opts \\ []) do
        %__MODULE__{lsp: LSP.new(opts)}
      end

      def to_elixir(%__MODULE__{} = request) do
        Convert.to_elixir(request)
      end
    end
  end

  defp build_parse(method) do
    quote do
      def parse(%{"method" => unquote(method), "id" => id, "jsonrpc" => "2.0"} = request) do
        params = Map.get(request, "params", %{})
        flattened_request = Map.merge(request, params)

        case LSP.parse(flattened_request) do
          {:ok, raw_lsp} ->
            struct_opts = [id: id, method: unquote(method), jsonrpc: "2.0", lsp: raw_lsp]
            request = struct(__MODULE__, struct_opts)
            {:ok, request}

          error ->
            error
        end
      end
    end
  end
end
