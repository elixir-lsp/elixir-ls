defmodule ElixirLS.LanguageServer.Experimental.CodeUnitTest do
  alias ElixirLS.LanguageServer.Experimental.CodeUnit

  use ExUnit.Case
  use ExUnitProperties
  import CodeUnit

  describe "utf8 offsets" do
    test "handles single-byte characters" do
      s = "do"
      assert 0 == utf8_offset(s, 0)
      assert 1 == utf8_offset(s, 1)
      assert 2 == utf8_offset(s, 2)
      assert 2 == utf8_offset(s, 3)
      assert 2 == utf8_offset(s, 4)
    end

    test "caps offsets at the end of the string and beyond" do
      line = "🎸"

      # reminder, the offsets below are utf-16
      # character code unit offsets, which differ
      # from utf8's, and can have gaps.

      assert 4 == utf8_offset(line, 1)
      assert 4 == utf8_offset(line, 2)
      assert 4 == utf8_offset(line, 3)
      assert 4 == utf8_offset(line, 4)
    end

    test "handles multi-byte characters properly" do
      line = "b🎸abc"

      # reminder, the offsets below are utf-16
      # character code unit offsets, which differ
      # from utf8's, and can have gaps.

      assert 0 == utf8_offset(line, 0)
      assert 1 == utf8_offset(line, 1)
      assert 5 == utf8_offset(line, 3)
      assert 6 == utf8_offset(line, 4)
      assert 7 == utf8_offset(line, 5)
      assert 8 == utf8_offset(line, 6)
      assert 8 == utf8_offset(line, 7)
    end
  end

  describe "utf16_offset/2" do
    test "handles single-byte characters" do
      s = "do"
      assert 0 == utf16_offset(s, 0)
      assert 1 == utf16_offset(s, 1)
      assert 2 == utf16_offset(s, 2)
      assert 2 == utf16_offset(s, 3)
      assert 2 == utf16_offset(s, 4)
    end

    test "caps offsets at the end of the string and beyond" do
      line = "🎸"
      assert 2 == utf16_offset(line, 1)
      assert 2 == utf16_offset(line, 2)
      assert 2 == utf16_offset(line, 3)
      assert 2 == utf16_offset(line, 4)
    end

    test "handles multi-byte characters properly" do
      # guitar is 2 code units in utf16 but 4 in utf8
      line = "b🎸abc"
      assert 0 == utf16_offset(line, 0)
      assert 1 == utf16_offset(line, 1)
      assert 3 == utf16_offset(line, 2)
      assert 4 == utf16_offset(line, 3)
      assert 5 == utf16_offset(line, 4)
      assert 6 == utf16_offset(line, 5)
      assert 6 == utf16_offset(line, 6)
    end
  end

  describe "converting to utf8" do
    test "bounds are respected" do
      assert {:error, :out_of_bounds} = to_utf16("h", 2)
    end

    test "with a multi-byte character" do
      line = "🏳️‍🌈"

      code_unit_count = count_utf8_code_units(line)

      assert to_utf8(line, 0) == {:ok, 0}
      assert to_utf8(line, 1) == {:error, :misaligned}
      assert to_utf8(line, 2) == {:ok, 4}
      assert to_utf8(line, 3) == {:ok, 7}
      assert to_utf8(line, 4) == {:ok, 10}
      assert to_utf8(line, 5) == {:error, :misaligned}
      assert to_utf8(line, 6) == {:ok, code_unit_count}
    end

    test "after a unicode character" do
      line = "    {\"🎸\",   \"ok\"}"

      assert to_utf8(line, 0) == {:ok, 0}
      assert to_utf8(line, 1) == {:ok, 1}
      assert to_utf8(line, 4) == {:ok, 4}
      assert to_utf8(line, 5) == {:ok, 5}
      assert to_utf8(line, 6) == {:ok, 6}
      assert to_utf8(line, 7) == {:error, :misaligned}
      # after the guitar character
      assert to_utf8(line, 8) == {:ok, 10}
      assert to_utf8(line, 9) == {:ok, 11}
      assert to_utf8(line, 10) == {:ok, 12}
      assert to_utf8(line, 11) == {:ok, 13}
      assert to_utf8(line, 12) == {:ok, 14}
      assert to_utf8(line, 13) == {:ok, 15}
      assert to_utf8(line, 17) == {:ok, 19}
    end
  end

  describe "converting to utf16" do
    test "respects bounds" do
      assert {:error, :out_of_bounds} = to_utf16("h", 2)
    end

    test "with a multi-byte character" do
      line = "🏳️‍🌈"

      code_unit_count = count_utf16_code_units(line)
      utf8_code_unit_count = count_utf8_code_units(line)

      assert to_utf16(line, 0) == {:ok, 0}
      assert to_utf16(line, 1) == {:error, :misaligned}
      assert to_utf16(line, 2) == {:error, :misaligned}
      assert to_utf16(line, 3) == {:error, :misaligned}
      assert to_utf16(line, 4) == {:ok, 2}
      assert to_utf16(line, utf8_code_unit_count - 1) == {:error, :misaligned}
      assert to_utf16(line, utf8_code_unit_count) == {:ok, code_unit_count}
    end

    test "after a multi-byte character" do
      line = "    {\"🎸\",   \"ok\"}"

      utf16_code_unit_count = count_utf16_code_units(line)
      utf8_code_unit_count = count_utf8_code_units(line)

      # before, the character, there is no difference between utf8 and utf16
      for index <- 0..5 do
        assert to_utf16(line, index) == {:ok, index}
      end

      assert to_utf16(line, 6) == {:ok, 6}
      assert to_utf16(line, 7) == {:error, :misaligned}
      assert to_utf16(line, 8) == {:error, :misaligned}
      assert to_utf16(line, 9) == {:error, :misaligned}

      for index <- 10..19 do
        assert to_utf16(line, index) == {:ok, index - 2}
      end

      assert to_utf16(line, utf8_code_unit_count - 1) == {:ok, utf16_code_unit_count - 1}
    end
  end

  property "to_utf8 and to_utf16 are inverses of each other" do
    check all(s <- filter(string(:printable), &utf8?/1)) do
      utf8_code_unit_count = count_utf8_code_units(s)
      utf16_unit_count = count_utf16_code_units(s)

      assert {:ok, utf16_unit} = to_utf16(s, utf8_code_unit_count)
      assert utf16_unit == utf16_unit_count

      assert {:ok, utf8_unit} = to_utf8(s, utf16_unit)
      assert utf8_unit == utf8_code_unit_count
    end
  end

  property "to_utf16 and to_utf8 are inverses" do
    check all(s <- filter(string(:printable), &utf8?/1)) do
      utf16_code_unit_count = count_utf16_code_units(s)
      utf8_code_unit_count = count_utf8_code_units(s)

      assert {:ok, utf8_code_unit} = to_utf8(s, utf16_code_unit_count)
      assert utf8_code_unit == utf8_code_unit_count

      assert {:ok, utf16_unit} = to_utf16(s, utf8_code_unit)
      assert utf16_unit == utf16_code_unit_count
    end
  end

  defp count_utf16_code_units(utf8_string) do
    utf8_string
    |> :unicode.characters_to_binary(:utf8, :utf16)
    |> byte_size()
    |> div(2)
  end

  defp count_utf8_code_units(utf8_string) do
    byte_size(utf8_string)
  end

  defp utf8?(<<_::utf8>>) do
    true
  end

  defp utf8?(<<_::utf8, rest::binary>>) do
    utf8?(rest)
  end

  defp utf8?(_) do
    false
  end
end
