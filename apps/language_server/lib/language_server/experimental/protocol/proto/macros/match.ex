defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Match do
  def build(field_types, dest_module) do
    macro_name =
      dest_module
      |> Macro.underscore()
      |> String.replace("/", "_")
      |> String.to_atom()

    quote location: :keep do
      defmacro unquote(macro_name)(opts \\ []) do
        cond do
          Keyword.keyword?(opts) ->
            %unquote(dest_module){unquote_splicing(field_types)}
        end
      end
    end

    nil
  end
end
