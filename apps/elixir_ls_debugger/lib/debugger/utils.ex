defmodule ElixirLS.Debugger.Utils do
  def parse_mfa(mfa_str) do
    case Code.string_to_quoted(mfa_str) do
      {:ok, {:/, _, [{{:., _, [mod, fun]}, _, []}, arity]}}
      when is_atom(fun) and is_integer(arity) ->
        case mod do
          atom when is_atom(atom) ->
            {:ok, {atom, fun, arity}}

          {:__aliases__, _, list} when is_list(list) ->
            {:ok, {list |> Module.concat(), fun, arity}}

          _ ->
            {:error, "cannot parse MFA"}
        end

      _ ->
        {:error, "cannot parse MFA"}
    end
  end
end
