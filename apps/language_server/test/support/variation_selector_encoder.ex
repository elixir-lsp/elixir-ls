defmodule VariationSelectorEncoder do
  @moduledoc """
  Encodes a message into a string whose characters are a base
  character followed by variation selectors representing each byte.

  The mapping is as follows:
    - For bytes less than 16, the variation selector is U+FE00 + byte.
    - For bytes ≥ 16, the variation selector is U+E0100 + (byte - 16).
  """

  # Converts a single byte into its corresponding variation selector character.
  defp byte_to_variation_selector(byte) when byte < 16 do
    <<0xFE00 + byte::utf8>>
  end

  defp byte_to_variation_selector(byte) do
    <<0xE0100 + (byte - 16)::utf8>>
  end

  @doc """
  Encodes a message by prepending the base character (e.g. an emoji)
  and appending variation selector characters representing the given bytes.
  """
  def encode(base, bytes) when is_binary(base) and is_binary(bytes) do
    for <<byte::8 <- bytes>>, into: base, do: byte_to_variation_selector(byte)
  end

  # Converts a variation selector codepoint (an integer) back into a byte.
  defp variation_selector_to_byte(codepoint)
       when codepoint in 0xFE00..0xFE0F do
    <<codepoint - 0xFE00>>
  end

  defp variation_selector_to_byte(codepoint)
       when codepoint in 0xE0100..0xE01EF do
    <<codepoint - 0xE0100 + 16>>
  end

  defp variation_selector_to_byte(_), do: <<>>

  @doc """
  Decodes a string created by `encode/2` and returns the list of bytes.

  It ignores characters with no variation selector.
  """
  def decode(encoded) when is_binary(encoded) do
    for <<codepoint::utf8 <- encoded>>, into: <<>> do
      variation_selector_to_byte(codepoint)
    end
  end
end

# Example usage:
# defmodule Main do
#   def run do
#     # Encode the bytes corresponding to "hello" using the base character 😊.
#     original = "hello"
#     char = "😊"
#     IO.puts("Original: " <> original)
#     IO.puts("Original bytes: " <> Base.encode16(original))
#     IO.puts("Char: " <> char)
#     IO.puts("Char bytes: " <> Base.encode16(char))
#     encoded = VariationSelectorEncoder.encode(char, original)

#     IO.puts("Encoded: " <> encoded)
#     IO.puts("Encoded bytes: " <> Base.encode16(encoded))

#     # Decode the message back into bytes.
#     decoded_bytes = VariationSelectorEncoder.decode(encoded)
#     IO.puts("Decoded: " <> decoded_bytes)
#     IO.puts("Decoded bytes: " <> Base.encode16(decoded_bytes))
#   end
# end

# Main.run()
