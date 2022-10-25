defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Parse do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Field
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Text

  def build(opts) do
    {optional_opts, required_opts} =
      Enum.split_with(opts, fn
        {_key, {:optional, _, _}} -> true
        {:.., _} -> true
        _ -> false
      end)

    {splat_opt, optional_opts} = Keyword.pop(optional_opts, :..)

    required_keys = Keyword.keys(required_opts)

    map_parameter_var =
      if Enum.empty?(optional_opts) && is_nil(splat_opt) do
        Macro.var(:_, nil)
      else
        Macro.var(:json_rpc_message, nil)
      end

    struct_keys = Keyword.keys(opts)

    map_vars = Map.new(struct_keys, fn k -> {k, Macro.var(k, nil)} end)

    map_keys = Enum.map(required_keys, &Text.camelize/1)

    map_pairs =
      map_vars
      |> Map.take(required_keys)
      |> Enum.map(fn {k, v} -> {Text.camelize(k), v} end)

    map_extractors = map_extractor(map_pairs)

    required_extractors =
      for {field_name, field_type} <- required_opts do
        quote location: :keep do
          {unquote(field_name),
           Field.extract(
             unquote(field_type),
             unquote(field_name),
             unquote(Map.get(map_vars, field_name))
           )}
        end
      end

    optional_extractors =
      for {field_name, field_type} <- optional_opts do
        quote location: :keep do
          {unquote(field_name),
           Field.extract(
             unquote(field_type),
             unquote(field_name),
             Map.get(unquote(map_parameter_var), unquote(Text.camelize(field_name)))
           )}
        end
      end

    splat_extractors =
      if splat_opt do
        known_keys = opts |> Keyword.keys() |> Enum.map(&Text.camelize/1)

        quoted_extractor =
          quote location: :keep do
            {(fn ->
                {:map, _, field_name} = unquote(splat_opt)
                field_name
              end).(),
             Field.extract(
               unquote(splat_opt),
               :..,
               Map.reject(unquote(map_parameter_var), fn {k, _} -> k in unquote(known_keys) end)
             )}
          end

        [quoted_extractor]
      else
        []
      end

    all_extractors = required_extractors ++ optional_extractors ++ splat_extractors
    error_parse = maybe_build_error_parse(required_extractors, map_keys)

    quote location: :keep do
      def parse(unquote(map_extractors) = unquote(map_parameter_var)) do
        result =
          unquote(all_extractors)
          |> Enum.reduce_while([], fn
            {field, {:ok, result}}, acc ->
              {:cont, [{field, result} | acc]}

            {field, {:error, _} = err}, acc ->
              {:halt, err}
          end)

        case result do
          {:error, _} = err -> err
          keyword when is_list(keyword) -> {:ok, struct(__MODULE__, keyword)}
        end
      end

      unquote(error_parse)

      def parse(not_map) do
        {:error, {:invalid_map, not_map}}
      end
    end
  end

  defp maybe_build_error_parse([], _) do
  end

  defp maybe_build_error_parse(_, map_keys) do
    # this is only built if there are required fields
    quote do
      def parse(%{} = unmatched) do
        missing_keys =
          Enum.reduce(unquote(map_keys), [], fn key, acc ->
            if Map.has_key?(unmatched, key) do
              acc
            else
              [key | acc]
            end
          end)

        {:error, {:missing_keys, missing_keys, __MODULE__}}
      end
    end
  end

  defp map_extractor(map_pairs) do
    quote location: :keep do
      %{unquote_splicing(map_pairs)}
    end
  end
end
