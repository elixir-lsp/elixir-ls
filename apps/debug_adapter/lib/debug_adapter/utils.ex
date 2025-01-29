defmodule ElixirLS.DebugAdapter.Utils do
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
    utf16_line = characters_to_binary!(utf8_line, :utf8, :utf16)
    max_bytes = byte_size(utf16_line)

    # LSP character -> code units -> bytes
    offset0 = dap_character * 2
    offset = clamp_offset_to_surrogate_boundary(utf16_line, offset0, max_bytes)

    partial = binary_part(utf16_line, 0, offset)
    partial_utf8 = characters_to_binary!(partial, :utf16, :utf8)
    String.length(partial_utf8)
  end

  # “Clamp” helper. 
  # - If offset is out of bounds, keep it within [0, max_bytes].
  # - Then check if we landed *immediately* after a high surrogate (0xD800..0xDBFF);
  #   if so, subtract 2 to avoid slicing in the middle.
  defp clamp_offset_to_surrogate_boundary(_bin, offset, max_bytes) when offset >= max_bytes,
    do: max_bytes

  defp clamp_offset_to_surrogate_boundary(_bin, offset, _max_bytes) when offset <= 0,
    do: 0

  defp clamp_offset_to_surrogate_boundary(bin, offset, _max_bytes) do
    # We know 0 < offset < max_bytes at this point
    # Look at the 2 bytes immediately before `offset`
    <<_::binary-size(offset - 2), maybe_high::binary-size(2), _::binary>> = bin
    code_unit = :binary.decode_unsigned(maybe_high, :big)

    # If that 16-bit code_unit is a high surrogate, we've sliced in half
    if code_unit in 0xD800..0xDBFF do
      offset - 2
    else
      offset
    end
  end
end
