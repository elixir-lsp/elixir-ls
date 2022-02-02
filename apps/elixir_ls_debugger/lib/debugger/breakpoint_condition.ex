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

  def register_condition(name \\ __MODULE__, module, lines, condition) do
    GenServer.call(name, {:register_condition, {module, lines}, condition})
  end

  def unregister_condition(name \\ __MODULE__, module, lines) do
    GenServer.cast(name, {:unregister_condition, {module, lines}})
  end

  def has_condition?(name \\ __MODULE__, module, lines) do
    GenServer.call(name, {:has_condition?, {module, lines}})
  end

  def get_condition(name \\ __MODULE__, number) do
    GenServer.call(name, {:get_condition, number})
  end

  @impl GenServer
  def init(_args) do
    {:ok,
     %{
       free: @range |> Enum.map(& &1),
       conditions: %{}
     }}
  end

  @impl GenServer
  def handle_call(
        {:register_condition, key, condition},
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
                conditions: conditions |> Map.put(key, {number, condition})
            }

            {:reply, {:ok, {__MODULE__, :"check_#{number}"}}, state}
        end

      {number, _old_condition} ->
        state = %{state | conditions: conditions |> Map.put(key, {number, condition})}
        {:reply, {:ok, {__MODULE__, :"check_#{number}"}}, state}
    end
  end

  def handle_call({:has_condition?, key}, _from, %{conditions: conditions} = state) do
    {:reply, Map.has_key?(conditions, key), state}
  end

  def handle_call({:get_condition, number}, _from, %{conditions: conditions} = state) do
    condition = conditions |> Map.values() |> Enum.find(fn {n, _c} -> n == number end) |> elem(1)
    {:reply, condition, state}
  end

  @impl GenServer
  def handle_cast({:unregister_condition, key}, %{free: free, conditions: conditions} = state) do
    state =
      case Map.pop(conditions, key) do
        {{number, _}, conditions} ->
          %{state | free: [number | free], conditions: conditions}

        {nil, _} ->
          state
      end

    {:noreply, state}
  end

  # `:int` module supports setting breakpoint conditions in the form `{module, function}`
  # we need a way of dynamically generating such pairs and assigning conditions that they will evaluate
  # an arbitrary limit of 100 conditions was chosen
  for i <- @range do
    @spec unquote(:"check_#{i}")(term) :: boolean
    def unquote(:"check_#{i}")(binding) do
      condition = get_condition(unquote(i))
      eval_condition(condition, binding)
    end
  end

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
