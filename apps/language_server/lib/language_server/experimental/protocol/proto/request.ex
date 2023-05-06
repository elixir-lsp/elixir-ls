defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Request do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Message
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.TypeFunctions

  import TypeFunctions, only: [optional: 1, literal: 1]

  defmacro defrequest(method, access, types) do
    CompileMetadata.add_request_module(__CALLER__.module)
    # id is optional so we can resuse the parse function. If it's required,
    # it will go in the pattern match for the params, which won't work.

    jsonrpc_types = [
      id: quote(do: optional(one_of([string(), integer()]))),
      jsonrpc: quote(do: literal("2.0")),
      method: quote(do: literal(unquote(method)))
    ]

    lsp_types = Keyword.merge(jsonrpc_types, types)
    elixir_types = Message.generate_elixir_types(__CALLER__.module, lsp_types)
    param_names = Keyword.keys(types)
    lsp_module_name = Module.concat(__CALLER__.module, LSP)

    quote location: :keep do
      defmodule LSP do
        unquote(Message.build({:request, :lsp}, method, access, lsp_types, param_names))

        def new(opts \\ []) do
          opts
          |> Keyword.merge(method: unquote(method), jsonrpc: "2.0")
          |> super()
        end
      end

      alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Convert
      alias LSP.Types

      unquote(
        Message.build({:request, :elixir}, method, access, elixir_types, param_names,
          include_parse?: false
        )
      )

      unquote(build_parse(method))

      def new(opts \\ []) do
        opts = Keyword.merge(opts, method: unquote(method), jsonrpc: "2.0")

        raw = LSP.new(opts)
        # use struct here because initially, the non-lsp struct doesn't have
        # to be filled out. Calling to_elixir fills it out.
        struct(__MODULE__, lsp: raw, id: raw.id, method: unquote(method), jsonrpc: "2.0")
      end

      def to_elixir(%__MODULE__{} = request) do
        Convert.to_elixir(request)
      end

      defimpl JasonVendored.Encoder, for: unquote(__CALLER__.module) do
        def encode(request, opts) do
          JasonVendored.Encoder.encode(request.lsp, opts)
        end
      end

      defimpl JasonVendored.Encoder, for: unquote(lsp_module_name) do
        def encode(request, opts) do
          %{
            id: request.id,
            jsonrpc: "2.0",
            method: unquote(method),
            params: Map.take(request, unquote(param_names))
          }
          |> JasonVendored.Encode.map(opts)
        end
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
