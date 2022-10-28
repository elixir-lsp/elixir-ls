defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Field do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Text

  def extract(:any, _, value) do
    {:ok, value}
  end

  def extract({:literal, same_value}, _name, same_value) do
    {:ok, same_value}
  end

  def extract({:optional, _}, _name, nil) do
    {:ok, nil}
  end

  def extract({:optional, type}, name, orig_val) do
    extract(type, name, orig_val)
  end

  def extract({:one_of, type_list}, name, value) do
    result =
      Enum.reduce_while(type_list, nil, fn type, _acc ->
        case extract(type, name, value) do
          {:ok, _} = success -> {:halt, success}
          error -> {:cont, error}
        end
      end)

    case result do
      {:ok, _} = success -> success
      _error -> {:error, {:incorrect_type, type_list, value}}
    end
  end

  def extract({:list, list_type}, name, orig_value) when is_list(orig_value) do
    result =
      Enum.reduce_while(orig_value, [], fn orig, acc ->
        case extract(list_type, name, orig) do
          {:ok, value} -> {:cont, [value | acc]}
          error -> {:halt, error}
        end
      end)

    case result do
      value_list when is_list(value_list) -> {:ok, Enum.reverse(value_list)}
      error -> error
    end
  end

  def extract(:integer, _name, orig_value) when is_integer(orig_value) do
    {:ok, orig_value}
  end

  def extract(:string, _name, orig_value) when is_binary(orig_value) do
    {:ok, orig_value}
  end

  def extract(:boolean, _name, orig_value) when is_boolean(orig_value) do
    {:ok, orig_value}
  end

  def extract(module, _name, orig_value)
      when is_atom(module) and module not in [:integer, :string, :boolean] do
    module.parse(orig_value)
  end

  def extract({:map, type, _opts}, field_name, field_value)
      when is_map(field_value) do
    result =
      Enum.reduce_while(field_value, [], fn {k, v}, acc ->
        case extract(type, field_name, v) do
          {:ok, value} -> {:cont, [{k, value} | acc]}
          error -> {:halt, error}
        end
      end)

    case result do
      values when is_list(values) -> {:ok, Map.new(values)}
      error -> error
    end
  end

  def extract({:params, param_defs}, _field_name, field_value)
      when is_map(field_value) do
    result =
      Enum.reduce_while(param_defs, [], fn {param_name, param_type}, acc ->
        value = Map.get(field_value, Text.camelize(param_name))

        case extract(param_type, param_name, value) do
          {:ok, value} -> {:cont, [{param_name, value} | acc]}
          error -> {:halt, error}
        end
      end)

    case result do
      values when is_list(values) -> {:ok, Map.new(values)}
      error -> error
    end
  end

  def extract(_type, name, orig_value) do
    {:error, {:invalid_value, name, orig_value}}
  end

  def encode(:any, field_value) do
    field_value
  end

  def encode({:literal, value}, _) do
    value
  end

  def encode({:optional, _}, nil) do
    :"$__drop__"
  end

  def encode({:optional, field_type}, field_value) do
    encode(field_type, field_value)
  end

  def encode({:one_of, types}, field_value) do
    Enum.reduce_while(types, nil, fn type, _ ->
      case encode(type, field_value) do
        {:ok, _} = success -> {:halt, success}
        error -> {:cont, error}
      end
    end)
  end

  def encode({:list, list_type}, field_value) when is_list(field_value) do
    Enum.map(field_value, &encode(list_type, &1))
  end

  def encode(:integer, field_value) do
    field_value
  end

  def encode(:string, field_value) when is_binary(field_value) do
    field_value
  end

  def encode(:boolean, field_value) when is_boolean(field_value) do
    field_value
  end

  def encode({:map, value_type, _}, field_value) when is_map(field_value) do
    Map.new(field_value, fn {k, v} -> {k, encode(value_type, v)} end)
  end

  def encode({:params, param_defs}, field_value) when is_map(field_value) do
    Map.new(param_defs, fn {param_name, param_type} ->
      {param_name, encode(param_type, Map.get(field_value, param_name))}
    end)
  end

  def encode({:constant, constant_module}, field_value) do
    constant_module.encode(field_value)
  end

  def encode(module, field_value) when is_atom(module) do
    if function_exported?(module, :encode, 1) do
      module.encode(field_value)
    else
      field_value
    end
  end

  def encode(_, nil) do
    nil
  end
end
