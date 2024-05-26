defmodule ElixirSenseExample.OverridableFunctions do
  defmacro __using__(_opts) do
    quote do
      @doc "Some overridable"
      @doc since: "1.2.3"
      @spec test(number, number) :: number
      def test(x, y) do
        x + y
      end

      defmacro required(var), do: Macro.expand(var, __CALLER__)

      defoverridable test: 2, required: 1
    end
  end
end

defmodule ElixirSenseExample.OverridableBehaviour do
  @callback foo :: any
  @macrocallback bar(any) :: Macro.t()
end

defmodule ElixirSenseExample.OverridableImplementation do
  alias ElixirSenseExample.OverridableBehaviour

  defmacro __using__(_opts) do
    quote do
      @behaviour OverridableBehaviour

      def foo do
        "Override me"
      end

      defmacro bar(var), do: Macro.expand(var, __CALLER__)

      defoverridable OverridableBehaviour
    end
  end
end

defmodule ElixirSenseExample.OverridableImplementation.Overrider do
  use ElixirSenseExample.OverridableImplementation

  def foo do
    super()
  end

  defmacro bar(any) do
    super(any)
  end
end

defmodule ElixirSenseExample.Overridable.Using do
  alias ElixirSenseExample.OverridableImplementation

  defmacro __using__(_opts) do
    quote do
      use OverridableImplementation
    end
  end
end
