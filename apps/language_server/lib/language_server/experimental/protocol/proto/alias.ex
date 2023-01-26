defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Alias do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata

  defmacro defalias(alias_definition) do
    caller_module = __CALLER__.module
    CompileMetadata.add_type_alias_module(caller_module)

    quote location: :keep do
      def definition do
        unquote(alias_definition)
      end

      def __meta__(:type) do
        :type_alias
      end

      def __meta__(:param_names) do
        []
      end
    end
  end
end
