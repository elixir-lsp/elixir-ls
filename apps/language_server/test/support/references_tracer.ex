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

  def trace({kind, meta, module, name, arity}, %Macro.Env{} = env)
      when kind in [:imported_function, :imported_macro, :remote_function, :remote_macro] do
    register_call(%{
      callee: {module, name, arity},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: kind
    })

    :ok
  end

  def trace({:imported_quoted, meta, module, name, arities}, %Macro.Env{} = env) do
    for arity <- arities do
      register_call(%{
        callee: {module, name, arity},
        file: env.file |> Path.relative_to_cwd(),
        line: meta[:line],
        column: meta[:column],
        kind: :imported_quoted
      })
    end

    :ok
  end

  def trace({kind, meta, name, arity}, %Macro.Env{} = env)
      when kind in [:local_function, :local_macro] do
    register_call(%{
      callee: {env.module, name, arity},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: kind
    })

    :ok
  end

  def trace({:alias_reference, meta, module}, %Macro.Env{} = env) do
    register_call(%{
      callee: {module, nil, nil},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: :alias_reference
    })

    :ok
  end

  def trace({:alias, meta, module, _as, _opts}, %Macro.Env{} = env) do
    register_call(%{
      callee: {module, nil, nil},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: :alias
    })

    :ok
  end

  def trace({kind, meta, module, _opts}, %Macro.Env{} = env) when kind in [:import, :require] do
    register_call(%{
      callee: {module, nil, nil},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: kind
    })

    :ok
  end

  def trace(:defmodule, %Macro.Env{} = env) do
    register_call(%{
      callee: {Kernel, :defmodule, 2},
      file: env.file |> Path.relative_to_cwd(),
      line: env.line,
      column: 1,
      kind: :imported_macro
    })

    :ok
  end

  def trace({:struct_expansion, meta, name, _assocs}, %Macro.Env{} = env) do
    register_call(%{
      callee: {name, nil, nil},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: :struct_expansion
    })

    :ok
  end

  def trace({:alias_expansion, meta, as, alias}, %Macro.Env{} = env) do
    register_call(%{
      callee: {as, nil, nil},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: :alias_expansion_as
    })

    register_call(%{
      callee: {alias, nil, nil},
      file: env.file |> Path.relative_to_cwd(),
      line: meta[:line],
      column: meta[:column],
      kind: :alias_expansion
    })

    :ok
  end

  def trace(_trace, _env) do
    :ok
  end
end
