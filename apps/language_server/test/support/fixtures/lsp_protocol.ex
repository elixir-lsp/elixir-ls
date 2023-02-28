defmodule ElixirLS.LanguageServer.Fixtures.LspProtocol do
  def build(module_to_build, opts \\ []) do
    unless Code.ensure_loaded?(module_to_build) do
      raise "Couldn't load #{inspect(module_to_build)}"
    end

    if function_exported?(module_to_build, :__meta__, 1) do
      protocol_module = ensure_protocol_module(module_to_build)
      params = Map.take(protocol_module.__meta__(:types), protocol_module.__meta__(:param_names))

      result =
        Enum.reduce_while(params, [], fn {field_name, field_type}, acc ->
          case build_field(field_type, field_name, opts) do
            {:ok, value} -> {:cont, [{field_name, value} | acc]}
            {:error, _} = err -> {:halt, err}
          end
        end)

      case result do
        args when is_list(args) ->
          args =
            case module_to_build.__meta__(:type) do
              {:notification, _} ->
                Keyword.put(args, :method, module_to_build.__meta__(:method_name))

              {:request, _} ->
                id =
                  opts
                  |> Keyword.get(:id, next_int())
                  |> to_string()

                args
                |> Keyword.put(:id, id)
                |> Keyword.put(:method, module_to_build.__meta__(:method_name))

              _ ->
                args
            end

          {:ok, module_to_build.new(args)}

        {:error, _} = err ->
          err
      end
    else
      {:error, {:invalid_module, module_to_build}}
    end
  end

  def params_for(type, opts \\ []) do
    with {:ok, built} <- build(type, opts) do
      params =
        built
        |> maybe_wrap_with_json_rpc(opts)
        |> camelize()

      {:ok, params}
    end
  end

  defp ensure_protocol_module(module_to_build) do
    case module_to_build.__meta__(:type) do
      {message_type, :lsp} when message_type in [:notification, :request] ->
        module_to_build

      {message_type, :elixir} when message_type in [:notification, :request] ->
        Module.concat(module_to_build, LSP)

      _ ->
        module_to_build
    end
  end

  defp maybe_wrap_with_json_rpc(%proto_module{} = proto, opts) do
    proto_struct =
      case proto_module.__meta__(:type) do
        {message_type, :lsp} when message_type in [:notification, :request] ->
          proto

        {message_type, :elixir} when message_type in [:notification, :request] ->
          proto.lsp

        other ->
          other
      end

    case proto_module.__meta__(:type) do
      {:notification, _} ->
        %{
          jsonrpc: Keyword.get(opts, :jsonrpc, "2.0"),
          method: proto_module.__meta__(:method_name),
          params: extract_params(proto_struct)
        }

      {:request, _} ->
        id =
          opts
          |> Keyword.get(:id, next_int())
          |> to_string()

        %{
          jsonrpc: Keyword.get(opts, :jsonrpc, "2.0"),
          method: proto_module.__meta__(:method_name),
          params: extract_params(proto_struct),
          id: id
        }

      _other ->
        proto_struct
    end
  end

  defp extract_params(%proto_module{} = proto) do
    Map.take(proto, proto_module.__meta__(:param_names))
  end

  defp build_field(type, field_name, opts) do
    set_value = Keyword.get(opts, field_name)

    with {:ok, built_value} <- build_field(type, field_name, set_value, opts) do
      {:ok, built_value}
    end
  end

  defp build_field({:literal, literal_value}, _, _, _) do
    {:ok, literal_value}
  end

  defp build_field({:optional, _type}, _, nil, _) do
    {:ok, nil}
  end

  defp build_field({:optional, type}, field_name, field_value, opts) do
    build_field(type, field_name, field_value, opts)
  end

  defp build_field(:integer, _field_name, field_value, _opts) when is_integer(field_value) do
    {:ok, field_value}
  end

  defp build_field(:integer, _field_name, nil, _) do
    {:ok, 0}
  end

  defp build_field({:list, elem_type}, field_name, field_value, opts) when is_list(field_value) do
    list_elements =
      Enum.reduce_while(field_value, [], fn set_value, acc ->
        case build_field(elem_type, field_name, set_value, opts) do
          {:ok, element} -> {:cont, [element | acc]}
          error -> {:halt, error}
        end
      end)

    case list_elements do
      elements when is_list(elements) -> {:ok, Enum.reverse(elements)}
      error -> error
    end
  end

  defp build_field({:params, param_types}, field_name, field_value, opts)
       when is_list(field_value) do
    build_field({:params, param_types}, field_name, Map.new(field_value), opts)
  end

  defp build_field({:params, param_types}, field_name, %{} = field_value, opts) do
    list_elements =
      Enum.reduce_while(param_types, [], fn {param_name, param_type}, acc ->
        case build_field(param_type, field_name, Map.get(field_value, param_name), opts) do
          {:ok, element} -> {:cont, [{param_name, element} | acc]}
          error -> {:halt, error}
        end
      end)
      |> Map.new()

    case list_elements do
      %{} = elements -> {:ok, elements}
      error -> error
    end
  end

  defp build_field({:list, elem_type}, field_name, field_value, opts) do
    with {:ok, field} <- build_field(elem_type, field_name, field_value, opts) do
      {:ok, [field]}
    end
  end

  defp build_field(:string, _, s, _) when is_binary(s) do
    {:ok, s}
  end

  defp build_field(:string, field_name, nil, _) do
    {:ok, "#{field_name}_#{next_int()}"}
  end

  defp build_field(:boolean, _, value, _) when is_boolean(value) do
    {:ok, value}
  end

  defp build_field(:boolean, _, _, _) do
    {:ok, true}
  end

  defp build_field({:map, key_type, value_type}, field_name, field_value, opts)
       when is_map(field_value) do
    results =
      Enum.reduce_while(field_value, [], fn {set_key, set_value}, acc ->
        with {:ok, key} <- build_field(key_type, field_name, set_key, opts),
             {:ok, value} <- build_field(value_type, field_name, set_value, opts) do
          {:cont, [{key, value} | acc]}
        else
          error ->
            {:halt, error}
        end
      end)

    case results do
      elements when is_list(elements) -> {:ok, Map.new(elements)}
      error -> error
    end
  end

  defp build_field(module, _, %module{} = field_value, _) do
    {:ok, field_value}
  end

  defp build_field(module, _field_name, field_value, _opts) when is_atom(module) do
    field_value = field_value || []
    build(module, field_value)
  end

  def next_int do
    System.unique_integer([:monotonic, :positive])
  end

  defp camelize(%_struct_module{} = struct) do
    struct
    |> Map.from_struct()
    |> camelize()
  end

  defp camelize(%{} = map) do
    Map.new(map, fn
      {k, v} when is_map(v) ->
        {camelize(k), camelize(v)}

      {k, v} when is_list(v) ->
        {camelize(k), Enum.map(v, &camelize/1)}

      {k, v} ->
        {camelize(k), v}
    end)
  end

  defp camelize(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> camelize()
  end

  defp camelize(s) when is_binary(s) do
    s
    |> Macro.camelize()
    |> downcase_first()
  end

  defp camelize(other) do
    other
  end

  defp downcase_first(<<c::utf8, rest::binary>>) do
    first_char =
      [c]
      |> List.to_string()
      |> String.downcase()

    first_char <> rest
  end

  defp downcase_first(b) do
    b
  end
end
