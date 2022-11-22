defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Struct do
  def build(opts) do
    keys = Keyword.keys(opts)
    required_keys = required_keys(opts)

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
      @enforce_keys unquote(required_keys)
      defstruct unquote(keys)

      def new(opts \\ []) do
        struct!(__MODULE__, opts)
      end

      defoverridable new: 0, new: 1
    end
  end

  defp required_keys(opts) do
    Enum.filter(opts, fn
      # ignore the splat, it's always optional
      {:.., _} -> false
      # an optional signifier tuple
      {_, {:optional, _}} -> false
      # ast for an optional signifier tuple
      {_, {:optional, _, _}} -> false
      # everything else is required
      _ -> true
    end)
    |> Keyword.keys()
  end
end
