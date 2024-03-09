defmodule ElixirSense.Core.References.Tracer do
  @moduledoc """
  Elixir Compiler tracer that registers function calls
  """
  use Agent

  @spec start_link(ElixirSense.call_trace_t()) :: Agent.on_start()
  def start_link(initial \\ %{}) do
    Agent.start_link(fn -> initial end, name: __MODULE__)
  end

  @spec get :: ElixirSense.call_trace_t()
  def get do
    Agent.get(__MODULE__, & &1)
  end

  @spec register_call(ElixirSense.call_t()) :: :ok
  def register_call(%{callee: callee} = call) do
    Agent.update(__MODULE__, fn calls ->
      updated_calls =
        case calls[callee] do
          nil -> [call]
          callee_calls -> [call | callee_calls]
        end

      calls |> Map.put(callee, updated_calls)
    end)
  end

  def trace({kind, meta, module, name, arity}, env)
      when kind in [:imported_function, :imported_macro, :remote_function, :remote_macro] do
    register_call(%{
      callee: {module, name, arity},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column]
    })

    :ok
  end

  def trace({kind, meta, name, arity}, env)
      when kind in [:local_function, :local_macro] do
    register_call(%{
      callee: {env.module, name, arity},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column]
    })

    :ok
  end

  def trace(_trace, _env) do
    :ok
  end
end
