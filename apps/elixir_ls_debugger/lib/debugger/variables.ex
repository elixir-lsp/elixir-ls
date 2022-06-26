defmodule ElixirLS.Debugger.Variables do
  @moduledoc """
  Helper functions for working with variables for paused processes
  """
  alias ElixirSense.Core.Introspection

  def child_type(var) when is_map(var), do: :named
  def child_type(var) when is_bitstring(var), do: :indexed
  def child_type(var) when is_tuple(var), do: :indexed

  def child_type(var) when is_list(var) do
    if Keyword.keyword?(var) do
      :named
    else
      :indexed
    end
  end

  def child_type(var) when is_function(var), do: :named

  def child_type(var) when is_pid(var) do
    case :erlang.process_info(var) do
      :undefined -> :indexed
      results -> :named
    end
  end

  def child_type(var) when is_port(var) do
    case :erlang.port_info(var) do
      :undefined -> :indexed
      results -> :named
    end
  end

  def child_type(_var), do: nil

  def children(var, start, count) when is_list(var) do
    start = start || 0
    count = count || Enum.count(var)

    sliced =
      var
      |> Enum.slice(start, count)

    if Keyword.keyword?(var) do
      sliced
    else
      sliced
      |> with_index_as_name(start)
    end
  end

  def children(var, start, count) when is_tuple(var) do
    children(Tuple.to_list(var), start, count)
  end

  def children(var, start, count) when is_bitstring(var) do
    start = start || 0
    count = if is_integer(count) and count > 0, do: count, else: :erlang.byte_size(var)
    slice_length = min(:erlang.bit_size(var) - 8 * start, 8 * count)
    <<_::bytes-size(start), slice::bitstring-size(slice_length), _::bitstring>> = var
    with_index_as_name(:erlang.bitstring_to_list(slice), start)
  end

  def children(var, start, count) when is_map(var) do
    children =
      var
      |> Map.to_list()
      |> Enum.slice(start || 0, count || map_size(var))

    for {key, value} <- children do
      name =
        if is_atom(key) and not Introspection.elixir_module?(key) do
          to_string(key)
        else
          inspect(key)
        end

      {name, value}
    end
  end

  def children(var, start, count) when is_function(var) do
    :erlang.fun_info(var)
    |> children(start, count)
  end

  def children(var, start, count) when is_pid(var) do
    case :erlang.process_info(var) do
      :undefined -> ["process is not alive"]
      results -> results
    end
    |> children(start, count)
  end

  def children(var, start, count) when is_port(var) do
    case :erlang.port_info(var) do
      :undefined -> ["port is not open"]
      results -> results
    end
    |> children(start, count)
  end

  def children(_var, _start, _count) do
    []
  end

  def num_children(var) when is_list(var) do
    Enum.count(var)
  end

  def num_children(var) when is_bitstring(var) do
    byte_size(var)
  end

  def num_children(var) when is_tuple(var) do
    tuple_size(var)
  end

  def num_children(var) when is_map(var) do
    map_size(var)
  end

  def num_children(var) when is_function(var) do
    :erlang.fun_info(var)
    |> Enum.count()
  end

  def num_children(var) when is_pid(var) do
    case :erlang.process_info(var) do
      :undefined -> 1
      results -> results |> Enum.count()
    end
  end

  def num_children(var) when is_port(var) do
    case :erlang.port_info(var) do
      :undefined -> 1
      results -> results |> Enum.count()
    end
  end

  def num_children(_var) do
    0
  end

  def type(var) when is_boolean(var), do: "boolean"
  def type(var) when is_nil(var), do: "nil"

  def type(var) when is_atom(var) do
    if Introspection.elixir_module?(var) do
      "module"
    else
      "atom"
    end
  end

  def type(var) when is_binary(var), do: "binary"
  def type(var) when is_bitstring(var), do: "bitstring"

  def type(var) when is_float(var), do: "float"
  def type(var) when is_function(var), do: "function"
  def type(var) when is_integer(var), do: "integer"

  def type(var) when is_list(var) do
    if Keyword.keyword?(var) and var != [] do
      "keyword"
    else
      "list"
    end
  end

  def type(%name{}), do: "%#{inspect(name)}{}"

  def type(var) when is_map(var), do: "map"

  def type(var) when is_number(var), do: "number"
  def type(var) when is_pid(var), do: "pid"
  def type(var) when is_port(var), do: "port"
  def type(var) when is_reference(var), do: "reference"
  def type(var) when is_tuple(var), do: "tuple"
  def type(_), do: "term"

  defp with_index_as_name(vars, start) do
    for {var, idx} <- Enum.with_index(vars, start) do
      {"#{idx}", var}
    end
  end
end
