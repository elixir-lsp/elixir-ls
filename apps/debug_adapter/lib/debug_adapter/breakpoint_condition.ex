defmodule ElixirLS.DebugAdapter.BreakpointCondition do
  @moduledoc """
  Server that tracks breakpoint conditions
  """

  use GenServer
  alias ElixirLS.DebugAdapter.Output
  @range 0..99

  def start_link(args) do
    GenServer.start_link(__MODULE__, Keyword.delete(args, :name),
      name: Keyword.get(args, :name, __MODULE__)
    )
  end

  @spec register_condition(
          module,
          module,
          [non_neg_integer],
          String.t(),
          String.t() | nil,
          non_neg_integer
        ) ::
          {:ok, {module, atom}} | {:error, :limit_reached}
  def register_condition(name \\ __MODULE__, module, lines, condition, log_message, hit_count) do
    GenServer.call(
      name,
      {:register_condition, {module, lines}, condition, log_message, hit_count}
    )
  end

  @spec unregister_condition(module, module, [non_neg_integer]) :: :ok
  def unregister_condition(name \\ __MODULE__, module, lines) do
    GenServer.cast(name, {:unregister_condition, {module, lines}})
  end

  @spec has_condition?(module, module, [non_neg_integer]) :: boolean
  def has_condition?(name \\ __MODULE__, module, lines) do
    GenServer.call(name, {:has_condition?, {module, lines}})
  end

  @spec get_condition(module, non_neg_integer) ::
          {String.t(), String.t(), non_neg_integer, non_neg_integer}
  def get_condition(name \\ __MODULE__, number) do
    GenServer.call(name, {:get_condition, number})
  end

  @spec register_hit(module, non_neg_integer) :: :ok
  def register_hit(name \\ __MODULE__, number) do
    GenServer.cast(name, {:register_hit, number})
  end

  def clear(name \\ __MODULE__) do
    GenServer.call(name, :clear)
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
  def terminate(reason, _state) do
    case reason do
      :normal ->
        :ok

      :shutdown ->
        :ok

      {:shutdown, _} ->
        :ok

      _other ->
        message = Exception.format_exit(reason)

        Output.telemetry(
          "dap_server_error",
          %{
            "elixir_ls.dap_process" => inspect(__MODULE__),
            "elixir_ls.dap_server_error" => message
          },
          %{}
        )

        Output.debugger_important("Terminating #{__MODULE__}: #{message}")
    end

    :ok
  end

  @impl GenServer
  def handle_call(
        {:register_condition, key, condition, log_message, hit_count},
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
                conditions:
                  conditions |> Map.put(key, {number, {condition, log_message, hit_count}})
            }

            {:reply, {:ok, {__MODULE__, :"check_#{number}"}}, state}
        end

      {number, _old_condition} ->
        state = %{
          state
          | conditions: conditions |> Map.put(key, {number, {condition, log_message, hit_count}})
        }

        {:reply, {:ok, {__MODULE__, :"check_#{number}"}}, state}
    end
  end

  def handle_call({:has_condition?, key}, _from, %{conditions: conditions} = state) do
    {:reply, Map.has_key?(conditions, key), state}
  end

  def handle_call({:get_condition, number}, _from, %{conditions: conditions, hits: hits} = state) do
    {condition, log_message, hit_count} =
      conditions |> Map.values() |> Enum.find(fn {n, _c} -> n == number end) |> elem(1)

    hits = hits |> Map.get(number, 0)
    {:reply, {condition, log_message, hit_count, hits}, state}
  end

  def handle_call(:clear, _from, _state) do
    {:ok, state} = init([])
    {:reply, :ok, state}
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
      {condition, log_message, hit_count, hits} = get_condition(unquote(i))
      elixir_binding = binding |> ElixirLS.DebugAdapter.Binding.to_elixir_variable_names()
      result = eval_condition(condition, elixir_binding)

      result =
        if result do
          register_hit(unquote(i))
          # do not break if hit count not reached
          hits + 1 > hit_count
        else
          result
        end

      if result and log_message != nil do
        # Debug Adapter Protocol:
        # If this attribute exists and is non-empty, the backend must not 'break' (stop)
        # but log the message instead. Expressions within {} are interpolated.
        Output.debugger_console(interpolate(log_message, elixir_binding))
        false
      else
        result
      end
    end
  end

  @spec eval_condition(String.t(), keyword) :: boolean
  def eval_condition("true", _binding), do: true

  def eval_condition(condition, elixir_binding) do
    try do
      {term, _bindings} = Code.eval_string(condition, elixir_binding)
      if term, do: true, else: false
    catch
      kind, error ->
        Output.debugger_important(
          "Error in conditional breakpoint: " <> Exception.format_banner(kind, error)
        )

        false
    end
  end

  def eval_string(expression, elixir_binding) do
    try do
      {term, _bindings} = Code.eval_string(expression, elixir_binding)
      to_string(term)
    catch
      kind, error ->
        Output.debugger_important(
          "Error in log message interpolation: " <> Exception.format_banner(kind, error)
        )

        ""
    end
  end

  def interpolate(format_string, elixir_binding) do
    interpolate(format_string, [], elixir_binding)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  def interpolate(<<>>, acc, _elixir_binding), do: acc

  def interpolate(<<"\\{", rest::binary>>, acc, elixir_binding),
    do: interpolate(rest, ["{" | acc], elixir_binding)

  def interpolate(<<"\\}", rest::binary>>, acc, elixir_binding),
    do: interpolate(rest, ["}" | acc], elixir_binding)

  def interpolate(<<"{", rest::binary>>, acc, elixir_binding) do
    case parse_expression(rest, []) do
      {:ok, expression_iolist, expression_rest} ->
        expression =
          expression_iolist
          |> Enum.reverse()
          |> IO.iodata_to_binary()

        eval_result = eval_string(expression, elixir_binding)
        interpolate(expression_rest, [eval_result | acc], elixir_binding)

      :error ->
        Output.debugger_important("Log message has unpaired or nested `{}`")
        acc
    end
  end

  def interpolate(<<char::binary-size(1), rest::binary>>, acc, elixir_binding),
    do: interpolate(rest, [char | acc], elixir_binding)

  def parse_expression(<<>>, _acc), do: :error
  def parse_expression(<<"\\{", rest::binary>>, acc), do: parse_expression(rest, ["{" | acc])
  def parse_expression(<<"\\}", rest::binary>>, acc), do: parse_expression(rest, ["}" | acc])
  def parse_expression(<<"{", _rest::binary>>, _acc), do: :error
  def parse_expression(<<"}", rest::binary>>, acc), do: {:ok, acc, rest}

  def parse_expression(<<char::binary-size(1), rest::binary>>, acc),
    do: parse_expression(rest, [char | acc])
end
