defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Notification do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Message

  defmacro defnotification(method, access, types \\ []) do
    CompileMetadata.add_notification_module(__CALLER__.module)

    jsonrpc_types = [
      jsonrpc: quote(do: literal("2.0")),
      method: quote(do: literal(unquote(method)))
    ]

    param_names = Keyword.keys(types)
    lsp_types = Keyword.merge(jsonrpc_types, types)
    elixir_types = Message.generate_elixir_types(__CALLER__.module, lsp_types)

    quote location: :keep do
      defmodule LSP do
        unquote(Message.build({:notification, :lsp}, method, access, lsp_types, param_names))
      end

      alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Convert

      unquote(
        Message.build({:notification, :elixir}, method, access, elixir_types, param_names,
          include_parse?: false
        )
      )

      unquote(build_parse(method))

      def new(opts \\ []) do
        %__MODULE__{lsp: LSP.new(opts), method: unquote(method)}
      end

      def to_elixir(%__MODULE__{} = request) do
        Convert.to_elixir(request)
      end
    end
  end

  defp build_parse(method) do
    quote do
      def parse(%{"method" => unquote(method), "jsonrpc" => "2.0"} = request) do
        params = Map.get(request, "params", %{})
        flattened_notificaiton = Map.merge(request, params)

        case LSP.parse(flattened_notificaiton) do
          {:ok, raw_lsp} ->
            struct_opts = [method: unquote(method), jsonrpc: "2.0", lsp: raw_lsp]
            notification = struct(__MODULE__, struct_opts)
            {:ok, notification}

          error ->
            error
        end
      end
    end
  end
end
