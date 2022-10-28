defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Message do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.{
    Access,
    Struct,
    Parse,
    Typespec,
    Meta
  }

  alias ElixirLS.LanguageServer.Experimental.SourceFile

  def build(meta_type, method, access, types, param_names, opts \\ []) do
    parse_fn =
      if Keyword.get(opts, :include_parse?, true) do
        Parse.build(types)
      end

    quote do
      unquote(Access.build())
      unquote(Struct.build(types))
      unquote(Typespec.build())
      unquote(parse_fn)
      unquote(Meta.build(types))

      def method do
        unquote(method)
      end

      def __meta__(:method_name) do
        unquote(method)
      end

      def __meta__(:type) do
        unquote(meta_type)
      end

      def __meta__(:param_names) do
        unquote(param_names)
      end

      def __meta__(:access) do
        unquote(access)
      end
    end
  end

  def generate_elixir_types(caller_module, message_types) do
    message_types
    |> Enum.reduce(message_types, fn
      {:text_document, _}, types ->
        Keyword.put(types, :source_file, quote(do: SourceFile))

      {:position, _}, types ->
        Keyword.put(types, :position, quote(do: SourceFile.Position))

      {:range, _}, types ->
        Keyword.put(types, :range, quote(do: SourceFile.Range))

      _, types ->
        types
    end)
    |> Keyword.put(:lsp, quote(do: unquote(caller_module).LSP))
  end
end
