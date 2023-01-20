defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Json do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Field

  def build(dest_module) do
    quote location: :keep do
      defimpl JasonVendored.Encoder, for: unquote(dest_module) do
        def encode(%struct_module{} = value, opts) do
          encoded_pairs =
            for {field_name, field_type} <- unquote(dest_module).__meta__(:types),
                field_value = get_field_value(value, field_name),
                {:ok, encoded_value} = Field.encode(field_type, field_value),
                encoded_value != :"$__drop__" do
              {field_name, encoded_value}
            end

          encoded_pairs
          |> Enum.flat_map(fn
            # flatten the spread into the current map
            {:.., value} when is_map(value) -> Enum.to_list(value)
            {k, v} -> [{camelize(k), v}]
          end)
          |> JasonVendored.Encode.keyword(opts)
        end

        defp get_field_value(%struct_module{} = struct, :..) do
          get_field_value(struct, struct_module.__meta__(:spread_alias))
        end

        defp get_field_value(struct, field_name) do
          Map.get(struct, field_name)
        end

        def camelize(field_name) do
          field_name
          |> to_string()
          |> Macro.camelize()
          |> downcase_first()
        end

        defp downcase_first(<<c::binary-size(1), rest::binary>>) do
          String.downcase(c) <> rest
        end
      end
    end
  end
end
