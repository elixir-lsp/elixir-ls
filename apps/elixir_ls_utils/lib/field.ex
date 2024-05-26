defmodule ElixirLS.Utils.Field do
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.State
  alias ElixirSense.Core.Normalized.Typespec
  alias ElixirSense.Core.TypeInfo

  def get_field_types(%Metadata{} = metadata, mod, include_private) when is_atom(mod) do
    case get_field_types_from_metadata(metadata, mod, include_private) do
      nil -> get_field_types_from_introspection(mod, include_private)
      res -> res
    end
  end

  defguardp type_is_public(kind, include_private) when kind == :type or include_private

  defp get_field_types_from_metadata(
         %Metadata{types: types},
         mod,
         include_private
       ) do
    case types[{mod, :t, 0}] do
      %State.TypeInfo{specs: [type_spec], kind: kind}
      when type_is_public(kind, include_private) ->
        case Code.string_to_quoted(type_spec) do
          {:ok, {:@, _, [{_kind, _, [spec]}]}} ->
            spec
            |> get_fields_from_struct_spec()

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp get_field_types_from_introspection(nil, _include_private), do: %{}

  defp get_field_types_from_introspection(mod, include_private) when is_atom(mod) do
    # assume struct typespec is t()
    case TypeInfo.get_type_spec(mod, :t, 0) do
      {kind, spec} when type_is_public(kind, include_private) ->
        spec
        |> Typespec.type_to_quoted()
        |> get_fields_from_struct_spec()

      _ ->
        %{}
    end
  end

  defp get_fields_from_struct_spec({:"::", _, [_, {:%, _meta1, [_mod, {:%{}, _meta2, fields}]}]}) do
    if Keyword.keyword?(fields) do
      Map.new(fields)
    else
      %{}
    end
  end

  defp get_fields_from_struct_spec(_), do: %{}
end
