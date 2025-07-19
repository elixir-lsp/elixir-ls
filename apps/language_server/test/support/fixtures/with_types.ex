defmodule ElixirLS.Test.WithTypes do
  @type no_arg :: :ok
  @type one_arg(t) :: {:ok, t}
  @type one_arg_named(t) :: {:ok, t, bar :: integer()}
  @opaque opaque_type :: {:ok, any()}
  @typep private_type :: {:ok, any()}

  @type multiple_arities(t) :: {:ok, t}
  @type multiple_arities(t, u) :: {:ok, t, u}

  @spec no_arg() :: :ok
  def no_arg, do: :ok
  @spec one_arg(term()) :: {:ok, term()}
  def one_arg(arg), do: {:ok, arg}

  @spec one_arg_named(foo :: term(), bar :: integer()) :: {:ok, term(), baz :: integer()}
  def one_arg_named(foo, bar), do: {:ok, foo, bar}

  @spec multiple_specs(term(), integer()) :: {:ok, term(), integer()}
  @spec multiple_specs(term(), float()) :: {:ok, term(), float()}
  def multiple_specs(arg1, arg2) do
    {:ok, arg1, arg2}
  end

  @spec multiple_arities(arg1 :: term()) :: {:ok, term()}
  def multiple_arities(arg1) do
    {:ok, arg1}
  end

  @spec multiple_arities(arg1 :: term(), arg2 :: term()) :: {:ok, term(), term()}
  def multiple_arities(arg1, arg2) do
    {:ok, arg1, arg2}
  end

  @spec bounded_fun(foo) :: {:ok, term()} when foo: term()
  def bounded_fun(foo) do
    {:ok, foo}
  end

  @spec macro(Macro.t()) :: Macro.t()
  defmacro macro(ast) do
    ast
  end

  @spec macro_bounded(foo) :: Macro.t() when foo: term()
  defmacro macro_bounded(ast) do
    ast
  end

  @callback callback_no_arg() :: :ok
  @callback callback_one_arg(term()) :: {:ok, term()}
  @callback callback_one_arg_named(foo :: term(), bar :: integer()) ::
              {:ok, term(), baz :: integer()}
  @callback callback_multiple_specs(term(), integer()) :: {:ok, term(), integer()}
  @callback callback_multiple_specs(term(), float()) :: {:ok, term(), float()}
  @callback callback_bounded_fun(foo) :: {:ok, term()} when foo: term()
  @macrocallback callback_macro(Macro.t()) :: Macro.t()
  @macrocallback callback_macro_bounded(foo) :: Macro.t() when foo: term()

  @callback callback_multiple_arities(arg1 :: term()) :: {:ok, term()}
  @callback callback_multiple_arities(arg1 :: term(), arg2 :: term()) :: {:ok, term(), term()}
end
