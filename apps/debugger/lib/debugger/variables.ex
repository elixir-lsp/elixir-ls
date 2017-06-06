defmodule ElixirLS.Debugger.Variables do
  @moduledoc """
  Helper functions for working with variables for paused processes
  """

  def child_type(var) when is_map(var), do: :named
  def child_type(var) when is_bitstring(var), do: :indexed
  def child_type(var) when is_tuple(var), do: :indexed
  def child_type(var) when is_list(var), do: :indexed
  def child_type(_var), do: nil

  def expandable?(var) do
    num_children(var) > 0
  end

  def children(var, start, count) when is_list(var) do
    start = start || 0
    count = count || Enum.count(var)
    var
    |> Enum.slice(start, count)
    |> with_index_as_name(start)
  end

  def children(var, start, count) when is_tuple(var) do
    children(Tuple.to_list(var), start, count)
  end

  def children(var, start, count) when is_bitstring(var) do
    start = start || 0
    count = if (is_integer(count) and count > 0), do: count, else: :erlang.byte_size(var)
    slice_length = min(:erlang.bit_size(var) - (8 * start), (8 * count))
    <<_ :: bytes-size(start), slice :: bitstring-size(slice_length), _ :: bitstring>> = var
    with_index_as_name(:erlang.bitstring_to_list(slice), start)
  end

  def children(var, start, count) when is_map(var) do
    children = 
      var
      |> Map.to_list
      |> Enum.slice(start || 0, count || map_size(var))

    for {key, value} <- children do
      name = 
        if is_atom(key) and not String.starts_with?(to_string(key), "Elixir.") do
          to_string(key)
        else
          inspect(key)
        end
      {name, value}
    end
  end

  def children(_var, _start, _count) do
    []
  end
  
  def num_children(var) when is_list(var) do
    Enum.count(var)
  end

  def num_children(var) when is_binary(var) do
    byte_size(var)
  end

  def num_children(var) when is_bitstring(var) do
    if byte_size(var) > 1, do: byte_size(var), else: 0
  end

  def num_children(var) when is_tuple(var) do 
    tuple_size(var)
  end

  def num_children(var) when is_map(var) do 
    map_size(var)
  end

  def num_children(_var) do
    0
  end

  def type(var) when is_atom(var), do: "atom"
  def type(var) when is_binary(var), do: "binary"
  def type(var) when is_bitstring(var), do: "bitstring"
  def type(var) when is_boolean(var), do: "boolean"
  def type(var) when is_float(var), do: "float"
  def type(var) when is_function(var), do: "function"
  def type(var) when is_integer(var), do: "integer"
  def type(var) when is_list(var), do: "list"
  def type(var) when is_map(var), do: "map"
  def type(var) when is_nil(var), do: "nil"
  def type(var) when is_number(var), do: "number"
  def type(var) when is_pid(var), do: "pid"
  def type(var) when is_port(var), do: "port"
  def type(var) when is_reference(var), do: "reference"
  def type(var) when is_tuple(var), do: "tuple"
  def type(_), do: "term"

  defp with_index_as_name(vars, start) do
    for {var, idx} <- Enum.with_index(vars, start || 0) do
      {"#{idx}", var}
    end
  end
end