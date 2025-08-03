defmodule ElixirSenseExample.ModuleWithDocs do
  @moduledoc """
  An example module
  """
  @moduledoc since: "1.2.3"

  @typedoc """
  An example type
  """
  @typedoc since: "1.1.0"
  @type some_type :: integer
  @typedoc false
  @type some_type_doc_false :: integer
  @type some_type_no_doc :: integer

  @typedoc """
  An example opaque type
  """
  @opaque opaque_type :: integer

  @doc """
  An example fun
  """
  @doc since: "1.1.0"
  @spec some_fun(integer, integer | nil) :: integer
  def some_fun(a, b \\ nil), do: a + b
  @doc false
  def some_fun_doc_false(a, b \\ nil), do: a + b
  def some_fun_no_doc(a, b \\ nil), do: a + b

  @doc """
  An example macro
  """
  @doc since: "1.1.0"
  @spec some_macro(Macro.t(), Macro.t() | nil) :: Macro.t()
  defmacro some_macro(a, b \\ nil), do: a + b
  @doc false
  defmacro some_macro_doc_false(a, b \\ nil), do: a + b
  defmacro some_macro_no_doc(a, b \\ nil), do: a + b

  @doc """
  An example callback
  """
  @doc since: "1.1.0"
  @callback some_callback(integer) :: atom
  @doc false
  @callback some_callback_doc_false(integer) :: atom
  @callback some_callback_no_doc(integer) :: atom

  @doc """
  An example callback
  """
  @doc since: "1.1.0"
  @macrocallback some_macrocallback(integer) :: atom
  @doc false
  @macrocallback some_macrocallback_doc_false(integer) :: atom
  @macrocallback some_macrocallback_no_doc(integer) :: atom

  @doc """
  An example fun
  """
  @doc deprecated: "This function will be removed in a future release"
  def soft_deprecated_fun(_a), do: :ok

  @doc """
  An example macro
  """
  @doc deprecated: "This macro will be removed in a future release"
  defmacro soft_deprecated_macro(_a), do: :ok

  # As of elixir 1.10 hard deprecation by @deprecated attribute is only supported for macros and functions

  @doc """
  An example fun
  """
  @deprecated "This function will be removed in a future release"
  def hard_deprecated_fun(_a), do: :ok

  @doc """
  An example macro
  """
  @deprecated "This macro will be removed in a future release"
  defmacro hard_deprecated_macro(_a), do: :ok

  @doc """
  An example callback
  """
  @doc deprecated: "This callback will be removed in a future release"
  @callback soft_deprecated_callback(integer) :: atom

  @doc """
  An example macrocallback
  """
  @doc deprecated: "This callback will be removed in a future release"
  @macrocallback soft_deprecated_macrocallback(integer) :: atom

  @typedoc """
  An example type
  """
  @typedoc deprecated: "This type will be removed in a future release"
  @type soft_deprecated_type :: integer

  @optional_callbacks soft_deprecated_callback: 1, soft_deprecated_macrocallback: 1
end

defmodule ElixirSenseExample.ModuleWithDocFalse do
  @moduledoc false
end

defmodule ElixirSenseExample.ModuleWithNoDocs do
end

defmodule ElixirSenseExample.SoftDeprecatedModule do
  @moduledoc """
  An example module
  """
  @moduledoc deprecated: "This module will be removed in a future release"
end

defmodule ElixirSenseExample.ModuleWithDelegates do
  @doc """
  A delegated function
  """
  defdelegate delegated_fun(a, b), to: ElixirSenseExample.ModuleWithDocs, as: :some_fun_no_doc
end
