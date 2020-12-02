defmodule ElixirLS.Test.MacroA do
  defmacro __using__(_) do
    quote do
      import ElixirLS.Test.MacroA

      def macro_a_func do
        :ok
      end
    end
  end

  def macro_imported_fun do
    :ok
  end
end
