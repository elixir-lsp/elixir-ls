defmodule ElixirLS.LanguageServer.CodeUnitTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.CodeUnit

  describe "basic UTF-8 to UTF-16 conversions" do
    test "converts simple ASCII text" do
      text = "hello"
      assert CodeUnit.utf16_offset(text, 0) == 0
      assert CodeUnit.utf16_offset(text, 1) == 1
      assert CodeUnit.utf16_offset(text, 5) == 5
    end

    test "converts text with multi-byte UTF-8 characters" do
      # é is 2 bytes in UTF-8, 1 code unit in UTF-16
      text = "héllo"
      assert CodeUnit.utf16_offset(text, 0) == 0
      # h
      assert CodeUnit.utf16_offset(text, 1) == 1
      # é (2 UTF-8 bytes, 1 UTF-16 code unit)
      assert CodeUnit.utf16_offset(text, 2) == 2
      # l
      assert CodeUnit.utf16_offset(text, 3) == 3
    end
  end

  describe "UTF-16 to UTF-8 conversions" do
    test "converts simple ASCII text" do
      text = "hello"
      assert CodeUnit.utf8_offset(text, 0) == 0
      assert CodeUnit.utf8_offset(text, 1) == 1
      assert CodeUnit.utf8_offset(text, 5) == 5
    end

    test "converts text with multi-byte UTF-8 characters" do
      # é is 2 bytes in UTF-8, 1 code unit in UTF-16
      text = "héllo"
      assert CodeUnit.utf8_offset(text, 0) == 0
      # h
      assert CodeUnit.utf8_offset(text, 1) == 1
      # after é (2 UTF-8 bytes)
      assert CodeUnit.utf8_offset(text, 2) == 3
      # l
      assert CodeUnit.utf8_offset(text, 3) == 4
    end
  end

  describe "surrogate pair handling" do
    test "handles text with surrogate pairs correctly" do
      # U+1F600 (😀) requires a surrogate pair in UTF-16
      text = "a😀b"

      # In UTF-8: "a" (1 byte) + "😀" (4 bytes) + "b" (1 byte) = 6 bytes total
      # In UTF-16: "a" (1 code unit) + "😀" (2 code units) + "b" (1 code unit) = 4 code units total

      # start
      assert CodeUnit.utf16_offset(text, 0) == 0
      # after 'a'
      assert CodeUnit.utf16_offset(text, 1) == 1
      # after '😀' (2 UTF-16 code units)
      assert CodeUnit.utf16_offset(text, 2) == 3
      # after 'b'
      assert CodeUnit.utf16_offset(text, 3) == 4
    end

    test "validates UTF-16 positions don't point to low surrogates" do
      text = "a😀b"

      # Position 0, 1, 3, 4 are valid (not pointing to low surrogate)
      assert CodeUnit.utf8_offset(text, 0) == 0
      assert CodeUnit.utf8_offset(text, 1) == 1
      # after 😀
      assert CodeUnit.utf8_offset(text, 3) == 5
      # after b
      assert CodeUnit.utf8_offset(text, 4) == 6

      # Position 2 points to the low surrogate of 😀, should be clamped to position 1
      # clamped to previous valid position
      assert CodeUnit.utf8_offset(text, 2) == 1
    end

    test "to_utf8 validates surrogate positions" do
      text = "a😀b"

      # Valid positions
      assert {:ok, 0} == CodeUnit.to_utf8(text, 0)
      assert {:ok, 1} == CodeUnit.to_utf8(text, 1)
      # after 😀
      assert {:ok, 5} == CodeUnit.to_utf8(text, 3)
      # after b
      assert {:ok, 6} == CodeUnit.to_utf8(text, 4)

      # Invalid position (points to low surrogate of 😀)
      assert {:error, :invalid_surrogate_position} == CodeUnit.to_utf8(text, 2)
    end

    test "handles multiple surrogate pairs" do
      # Two emoji characters
      text = "😀😃"

      # Each emoji is 2 UTF-16 code units
      # start
      assert CodeUnit.utf16_offset(text, 0) == 0
      # after first emoji
      assert CodeUnit.utf16_offset(text, 1) == 2
      # after second emoji
      assert CodeUnit.utf16_offset(text, 2) == 4

      # UTF-8 positions
      # start
      assert CodeUnit.utf8_offset(text, 0) == 0
      # after first emoji (4 UTF-8 bytes)
      assert CodeUnit.utf8_offset(text, 2) == 4
      # after second emoji (8 UTF-8 bytes total)
      assert CodeUnit.utf8_offset(text, 4) == 8

      # Invalid positions (pointing to low surrogates)
      # clamped to previous valid
      assert CodeUnit.utf8_offset(text, 1) == 0
      # clamped to previous valid
      assert CodeUnit.utf8_offset(text, 3) == 4
    end
  end

  describe "UTF-16 counting" do
    test "counts UTF-16 code units correctly" do
      assert CodeUnit.count(:utf16, "hello") == 5
      # é is 1 UTF-16 code unit
      assert CodeUnit.count(:utf16, "héllo") == 5
      # emoji is 2 UTF-16 code units
      assert CodeUnit.count(:utf16, "😀") == 2
      # a + 😀 + b = 1 + 2 + 1
      assert CodeUnit.count(:utf16, "a😀b") == 4
    end
  end

  describe "BMP (Basic Multilingual Plane) characters" do
    test "handles BMP characters correctly" do
      # Basic Latin (ASCII)
      text = "Hello"
      assert CodeUnit.count(:utf16, text) == 5
      assert CodeUnit.utf16_offset(text, 0) == 0
      assert CodeUnit.utf16_offset(text, 5) == 5

      # Extended Latin
      # é is U+00E9 (BMP)
      text = "café"
      assert CodeUnit.count(:utf16, text) == 4
      assert CodeUnit.utf16_offset(text, 0) == 0
      assert CodeUnit.utf16_offset(text, 4) == 4

      # Greek letters (BMP)
      # Greek letters in BMP
      text = "αβγ"
      assert CodeUnit.count(:utf16, text) == 3
      assert CodeUnit.utf16_offset(text, 0) == 0
      assert CodeUnit.utf16_offset(text, 3) == 3
    end

    test "handles BMP symbols and punctuation" do
      # Various BMP symbols
      # Copyright, registered, trademark symbols
      text = "©®™"
      assert CodeUnit.count(:utf16, text) == 3

      # Currency symbols
      # Euro, Pound, Yen
      text = "€£¥"
      assert CodeUnit.count(:utf16, text) == 3

      # Mathematical symbols in BMP
      # For all, exists, empty set
      text = "∀∃∅"
      assert CodeUnit.count(:utf16, text) == 3
    end

    test "BMP variation selectors" do
      # BMP variation selector (U+FE00-U+FE0F range)
      # Base character + BMP variation selector = 2 code units, but may form 1 grapheme
      # A + variation selector-16
      text = "A\uFE0F"
      assert CodeUnit.count(:utf16, text) == 2

      # Conversions should work without errors
      assert CodeUnit.utf16_offset(text, 0) == 0
      assert CodeUnit.utf16_offset(text, 1) == 1
      assert CodeUnit.utf16_offset(text, 2) == 2

      assert CodeUnit.utf8_offset(text, 0) == 0
      assert CodeUnit.utf8_offset(text, 1) == 1
      # A (1 byte) + variation selector (3 bytes)
      assert CodeUnit.utf8_offset(text, 2) == 4
    end
  end

  describe "supplementary range characters" do
    test "handles supplementary characters (surrogate pairs)" do
      # Mathematical script capitals (U+1D400-U+1D7FF)
      # Mathematical script A and B (U+1D49C, U+1D49D)
      text = "𝒜𝒝"
      # Each char needs 2 UTF-16 code units
      assert CodeUnit.count(:utf16, text) == 4

      # UTF-16 offsets
      # start
      assert CodeUnit.utf16_offset(text, 0) == 0
      # after first char (2 code units)
      assert CodeUnit.utf16_offset(text, 1) == 2
      # after second char (4 code units total)
      assert CodeUnit.utf16_offset(text, 2) == 4

      # UTF-8 conversions
      # start
      assert CodeUnit.utf8_offset(text, 0) == 0
      # after first char (4 UTF-8 bytes)
      assert CodeUnit.utf8_offset(text, 2) == 4
      # after second char (8 UTF-8 bytes total)
      assert CodeUnit.utf8_offset(text, 4) == 8
    end

    test "handles emoji in supplementary range" do
      # Common emoji requiring surrogate pairs
      # Rocket, glowing star, star
      text = "🚀🌟⭐"

      # Count UTF-16 code units (emojis need 2 each, star might be BMP)
      utf16_count = CodeUnit.count(:utf16, text)
      # At least 3, possibly more if all need surrogate pairs
      assert utf16_count >= 3

      # Basic conversion tests
      assert CodeUnit.utf16_offset(text, 0) == 0
      assert CodeUnit.utf8_offset(text, 0) == 0

      # Should handle all positions without crashing
      for i <- 0..utf16_count do
        utf8_pos = CodeUnit.utf8_offset(text, i)
        assert utf8_pos >= 0
        assert utf8_pos <= byte_size(text)
      end
    end

    test "handles supplementary variation selectors" do
      # Supplementary variation selectors (U+E0100-U+E01EF)
      # These require surrogate pairs in UTF-16
      # A + supplementary variation selector + B
      text = "A\u{E0100}B"

      utf16_count = CodeUnit.count(:utf16, text)
      # A (1) + variation selector (2) + B (1) = 4 code units
      assert utf16_count == 4

      # Test conversions handle surrogate pairs correctly
      # A
      assert CodeUnit.utf16_offset(text, 0) == 0
      # start of variation selector
      assert CodeUnit.utf16_offset(text, 1) == 1
      # after variation selector (2 code units)
      assert CodeUnit.utf16_offset(text, 2) == 3
      # B
      assert CodeUnit.utf16_offset(text, 3) == 4

      # UTF-8 conversions
      # start
      assert CodeUnit.utf8_offset(text, 0) == 0
      # after A
      assert CodeUnit.utf8_offset(text, 1) == 1
      # after variation selector (4 UTF-8 bytes)
      assert CodeUnit.utf8_offset(text, 3) == 5
      # after B
      assert CodeUnit.utf8_offset(text, 4) == 6

      # Test that positions pointing to low surrogates are handled safely
      # Position 2 would point to low surrogate of variation selector
      result = CodeUnit.utf8_offset(text, 2)
      # Should clamp to before the surrogate pair
      assert result == 1
    end

    test "handles mixed BMP and supplementary characters" do
      # Mix of BMP and supplementary characters
      # BMP + supplementary + BMP
      text = "A🎨B"

      utf16_count = CodeUnit.count(:utf16, text)
      # A (1) + 🎨 (2) + B (1) = 4 code units
      assert utf16_count == 4

      # Test specific positions
      # A
      assert CodeUnit.utf16_offset(text, 0) == 0
      # start of 🎨
      assert CodeUnit.utf16_offset(text, 1) == 1
      # after 🎨
      assert CodeUnit.utf16_offset(text, 2) == 3
      # B
      assert CodeUnit.utf16_offset(text, 3) == 4

      # Test UTF-8 conversions
      # start
      assert CodeUnit.utf8_offset(text, 0) == 0
      # after A
      assert CodeUnit.utf8_offset(text, 1) == 1
      # after 🎨 (4 UTF-8 bytes)
      assert CodeUnit.utf8_offset(text, 3) == 5
      # after B
      assert CodeUnit.utf8_offset(text, 4) == 6

      # Position 2 points to low surrogate, should clamp
      # clamps to before emoji
      assert CodeUnit.utf8_offset(text, 2) == 1
    end

    test "boundary cases between BMP and supplementary" do
      # Test characters near the BMP boundary (U+FFFF)
      # Last BMP char + first supplementary + replacement char
      text = "\uFFFE\u{10000}\uFFFF"

      utf16_count = CodeUnit.count(:utf16, text)
      # 1 + 2 + 1 = 4 code units
      assert utf16_count == 4

      # Should handle conversions without errors
      for i <- 0..utf16_count do
        utf8_pos = CodeUnit.utf8_offset(text, i)
        assert utf8_pos >= 0
        assert utf8_pos <= byte_size(text)

        # Test round-trip safety
        utf16_pos = CodeUnit.utf16_offset(text, utf8_pos)
        assert utf16_pos >= 0
        assert utf16_pos <= utf16_count
      end
    end
  end

  describe "edge cases" do
    test "handles empty strings" do
      assert CodeUnit.utf16_offset("", 0) == 0
      assert CodeUnit.utf8_offset("", 0) == 0
      assert {:ok, 0} == CodeUnit.to_utf8("", 0)
      assert {:ok, 0} == CodeUnit.to_utf16("", 0)
    end

    test "handles out of bounds positions gracefully" do
      text = "hello"

      # Should clamp to end of string
      assert CodeUnit.utf16_offset(text, 100) == 5
      assert CodeUnit.utf8_offset(text, 100) == 5
    end

    test "handles mixed content with surrogate pairs and regular characters" do
      text = "Hello 😀 World 🌍!"

      # This should work without errors and handle surrogate pairs correctly
      utf16_count = CodeUnit.count(:utf16, text)
      # More UTF-16 code units than characters due to emojis
      assert utf16_count > String.length(text)

      # Test that all positions can be converted without crashing
      # and produce reasonable results
      for i <- 0..utf16_count do
        utf8_pos = CodeUnit.utf8_offset(text, i)

        # UTF-8 position should be valid
        assert utf8_pos >= 0
        assert utf8_pos <= byte_size(text)

        # Should be able to convert back to UTF-16
        utf16_pos = CodeUnit.utf16_offset(text, utf8_pos)
        assert utf16_pos >= 0
        assert utf16_pos <= utf16_count

        # Converting back to UTF-8 should not crash
        utf8_pos2 = CodeUnit.utf8_offset(text, utf16_pos)
        assert utf8_pos2 >= 0
        assert utf8_pos2 <= byte_size(text)
      end

      # Test specific safe positions that we know should work
      # start
      assert CodeUnit.utf8_offset(text, 0) == 0
      # start
      assert CodeUnit.utf16_offset(text, 0) == 0

      # Test that basic conversions work without crashing
      assert CodeUnit.utf8_offset(text, 6) >= 0
      assert CodeUnit.utf16_offset(text, 6) >= 0
    end
  end
end
