defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Enum do
  defmacro defenum(opts) do
    parse_functions =
      for {name, value} <- opts do
        quote location: :keep do
          def parse(unquote(value)) do
            {:ok, unquote(name)}
          end
        end
      end

    enum_macros =
      for {name, value} <- opts do
        quote location: :keep do
          defmacro unquote(name)() do
            unquote(value)
          end
        end
      end

    encoders =
      for {name, value} <- opts do
        quote location: :keep do
          def encode(unquote(name)) do
            unquote(value)
          end
        end
      end

    quote location: :keep do
      unquote(parse_functions)

      def parse(unknown) do
        {:error, {:invalid_constant, unknown}}
      end

      unquote_splicing(encoders)

      unquote_splicing(enum_macros)

      def __meta__(:types) do
        {:constant, __MODULE__}
      end

      def __meta__(:type) do
        :enum
      end
    end
  end
end
