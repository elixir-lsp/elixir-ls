defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Meta do
  def build(opts) do
    field_types =
      for {field_name, field_type} <- opts do
        field_meta(field_name, field_type)
      end

    quote location: :keep do
      unquote_splicing(field_types)

      def __meta__(:types) do
        %{unquote_splicing(opts)}
      end
    end
  end

  defp field_meta(:.., {:map_of, ctx, [key_type, [as: key_alias]]}) do
    # a spread operator, generate meta for both the spread name and the aliased name

    quote do
      def __meta__(:spread_alias) do
        unquote(key_alias)
      end

      unquote(field_meta(:.., {:map_of, ctx, [key_type]}))
      unquote(field_meta(key_alias, {:map_of, ctx, [key_type]}))
    end
  end

  defp field_meta(field_name, field_type) do
    quote location: :keep do
      def __meta__(:type, unquote(field_name)) do
        unquote(field_type)
      end
    end
  end
end
