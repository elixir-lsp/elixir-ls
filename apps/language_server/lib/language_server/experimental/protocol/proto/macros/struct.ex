defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Struct do
  def build(opts) do
    keys = Keyword.keys(opts)

    keys =
      if :.. in keys do
        {splat_def, rest} = Keyword.pop(opts, :..)

        quote location: :keep do
          [
            (fn ->
               {_, _, field_name} = unquote(splat_def)
               field_name
             end).()
            | unquote(rest)
          ]
        end
      else
        keys
      end

    quote location: :keep do
      defstruct unquote(keys)

      def new(opts \\ []) do
        struct(__MODULE__, opts)
      end

      defoverridable new: 0, new: 1
    end
  end
end
