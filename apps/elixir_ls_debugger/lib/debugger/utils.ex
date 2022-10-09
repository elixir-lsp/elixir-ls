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

  defp characters_to_binary!(binary, from, to) do
    case :unicode.characters_to_binary(binary, from, to) do
      result when is_binary(result) -> result
    end
  end

  def dap_character_to_elixir(_utf8_line, dap_character) when dap_character <= 0, do: 0

  def dap_character_to_elixir(utf8_line, dap_character) do
    utf16_line =
      utf8_line
      |> characters_to_binary!(:utf8, :utf16)

    byte_size = byte_size(utf16_line)

    # if character index is over the length of the string assume we pad it with spaces (1 byte in utf8)
    diff = div(max(dap_character * 2 - byte_size, 0), 2)

    utf8_character =
      utf16_line
      |> (&binary_part(
            &1,
            0,
            min(dap_character * 2, byte_size)
          )).()
      |> characters_to_binary!(:utf16, :utf8)
      |> String.length()

    utf8_character + diff
  end
end
