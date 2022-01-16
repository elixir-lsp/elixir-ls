defmodule ElixirLS.Debugger.BreakpointCondition do
  @moduledoc """
  Server that tracks breakpoint conditions
  """

  use GenServer
  @range 0..99

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.delete(args, :name),
      name: Keyword.get(args, :name, __MODULE__)
    )
  end

  @spec register_condition(module, module, [non_neg_integer], String.t(), non_neg_integer) ::
          {:ok, {module, atom}} | {:error, :limit_reached}
  def register_condition(name \\ __MODULE__, module, lines, condition, hit_count) do
    GenServer.call(name, {:register_condition, {module, lines}, condition, hit_count})
  end

  @spec unregister_condition(module, module, [non_neg_integer]) :: :ok
  def unregister_condition(name \\ __MODULE__, module, lines) do
    GenServer.cast(name, {:unregister_condition, {module, lines}})
  end

  @spec has_condition?(module, module, [non_neg_integer]) :: boolean
  def has_condition?(name \\ __MODULE__, module, lines) do
    GenServer.call(name, {:has_condition?, {module, lines}})
  end

  @spec get_condition(module, non_neg_integer) :: {String.t(), non_neg_integer, non_neg_integer}
  def get_condition(name \\ __MODULE__, number) do
    GenServer.call(name, {:get_condition, number})
  end

  @spec register_hit(module, non_neg_integer) :: :ok
  def register_hit(name \\ __MODULE__, number) do
    GenServer.cast(name, {:register_hit, number})
  end

  @impl GenServer
  def init(_args) do
    {:ok,
     %{
       free: @range |> Enum.map(& &1),
       conditions: %{},
       hits: %{}
     }}
  end

  @impl GenServer
  def handle_call(
        {:register_condition, key, condition, hit_count},
        _from,
        %{free: free, conditions: conditions} = state
      ) do
    case conditions[key] do
      nil ->
        case free do
          [] ->
            {:reply, {:error, :limit_reached}, state}

          [number | rest] ->
            state = %{
              state
              | free: rest,
                conditions: conditions |> Map.put(key, {number, {condition, hit_count}})
            }

            {:reply, {:ok, {__MODULE__, :"check_#{number}"}}, state}
        end

      {number, _old_condition} ->
        state = %{
          state
          | conditions: conditions |> Map.put(key, {number, {condition, hit_count}})
        }

        {:reply, {:ok, {__MODULE__, :"check_#{number}"}}, state}
    end
  end

  def handle_call({:has_condition?, key}, _from, %{conditions: conditions} = state) do
    {:reply, Map.has_key?(conditions, key), state}
  end

  def handle_call({:get_condition, number}, _from, %{conditions: conditions, hits: hits} = state) do
    {condition, hit_count} =
      conditions |> Map.values() |> Enum.find(fn {n, _c} -> n == number end) |> elem(1)

    hits = hits |> Map.get(number, 0)
    {:reply, {condition, hit_count, hits}, state}
  end

  @impl GenServer
  def handle_cast(
        {:unregister_condition, key},
        %{free: free, conditions: conditions, hits: hits} = state
      ) do
    state =
      case Map.pop(conditions, key) do
        {{number, _}, conditions} ->
          %{
            state
            | free: [number | free],
              conditions: conditions,
              hits: hits |> Map.delete(number)
          }

        {nil, _} ->
          state
      end

    {:noreply, state}
  end

  def handle_cast({:register_hit, number}, %{hits: hits} = state) do
    hits = hits |> Map.update(number, 1, &(&1 + 1))
    {:noreply, %{state | hits: hits}}
  end

  # `:int` module supports setting breakpoint conditions in the form `{module, function}`
  # we need a way of dynamically generating such pairs and assigning conditions that they will evaluate
  # an arbitrary limit of 100 conditions was chosen
  for i <- @range do
    @spec unquote(:"check_#{i}")(term) :: boolean
    def unquote(:"check_#{i}")(binding) do
      {condition, hit_count, hits} = get_condition(unquote(i))
      result = eval_condition(condition, binding)

      if result and hit_count > 0 do
        register_hit(unquote(i))
        hits + 1 > hit_count
      else
        result
      end
    end
  end

  def eval_condition("true", _binding), do: true

  def eval_condition(condition, binding) do
    elixir_binding = binding |> ElixirLS.Debugger.Binding.to_elixir_variable_names()

    try do
      {term, _bindings} = Code.eval_string(condition, elixir_binding)
      if term, do: true, else: false
    catch
      kind, error ->
        IO.warn("Error in conditional breakpoint: " <> Exception.format_banner(kind, error))
        false
    end
  end
end
