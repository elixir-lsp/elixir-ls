defmodule ElixirSenseExample.Macros do
  defmacro go do
    quote do
      @type my_type :: nil
      def my_fun(), do: :ok
    end
  end
end

defmodule ElixirSenseExample.MacroGenerated do
  require ElixirSenseExample.Macros

  ElixirSenseExample.Macros.go()
end
