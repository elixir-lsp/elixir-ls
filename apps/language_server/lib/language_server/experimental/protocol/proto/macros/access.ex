defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Access do
  def build do
    quote location: :keep do
      def fetch(proto, key) when is_map_key(proto, key) do
        {:ok, Map.get(proto, key)}
      end

      def fetch(_, _) do
        :error
      end

      def get_and_update(proto, key, function) when is_map_key(proto, key) do
        old_value = Map.get(proto, key)

        case function.(old_value) do
          {current_value, updated_value} -> {current_value, Map.put(proto, key, updated_value)}
          :pop -> {old_value, Map.put(proto, key, nil)}
        end
      end

      def get_and_update(proto, key, function) do
        {{:error, {:nonexistent_key, key}}, proto}
      end

      def pop(proto, key) when is_map_key(proto, key) do
        {Map.get(proto, key), proto}
      end

      def pop(proto, _key) do
        {nil, proto}
      end
    end
  end
end
