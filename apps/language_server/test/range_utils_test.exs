defmodule ElixirLS.LanguageServer.RangeUtilsTest do
  use ExUnit.Case

  import ElixirLS.LanguageServer.Protocol
  import ElixirLS.LanguageServer.RangeUtils

  describe "valid?/1" do
    test "returns true if range is valid" do
      assert valid?(range(0, 0, 0, 0))
      assert valid?(range(1, 1, 1, 2))
      assert valid?(range(1, 1, 2, 0))
      assert valid?(range(1, 1, 2, 6))
    end

    test "returns false if range is invalid" do
      refute valid?(range(1, 1, 1, 0))
      refute valid?(range(1, 1, 0, 1))
      refute valid?(range(-1, 1, 5, 5))
      refute valid?(range(1, -1, 5, 5))
      refute valid?(range(1, 1, -5, 5))
      refute valid?(range(1, 1, 5, -5))
      refute valid?(range(1, 1, 5, nil))
      refute valid?(range(1, 1, nil, 5))
      refute valid?(range(1, nil, 5, 5))
      refute valid?(range(nil, 1, 5, 5))
    end
  end

  describe "left_in_right?" do
    test "returns true if range 1 is inside range 2" do
      range1 = range(2, 1, 3, 20)
      range2 = range(1, 2, 4, 15)
      assert left_in_right?(range1, range2)
    end

    test "returns true if range 1 is inside range 2 columns equal" do
      range1 = range(2, 1, 3, 20)
      range2 = range(2, 1, 3, 20)
      assert left_in_right?(range1, range2)
    end

    test "returns true if range 1 is inside range 2 same line" do
      range1 = range(1, 5, 1, 10)
      range2 = range(1, 2, 1, 15)
      assert left_in_right?(range1, range2)
    end

    test "returns false if ranges overlap but range 1 is wider" do
      range2 = range(2, 1, 3, 20)

      range1 = range(2, 0, 3, 20)
      refute left_in_right?(range1, range2)

      range1 = range(2, 1, 3, 21)
      refute left_in_right?(range1, range2)

      range1 = range(1, 1, 3, 21)
      refute left_in_right?(range1, range2)

      range1 = range(2, 1, 4, 21)
      refute left_in_right?(range1, range2)
    end

    test "returns false if range 1 starts after range 2" do
      range1 = range(3, 5, 4, 10)
      range2 = range(1, 2, 2, 15)
      refute left_in_right?(range1, range2)
    end

    test "returns false if range 1 starts after range 2 same line" do
      range1 = range(1, 16, 1, 18)
      range2 = range(1, 2, 1, 15)
      refute left_in_right?(range1, range2)
    end

    test "returns false if range 1 ends before range 2" do
      range1 = range(1, 5, 2, 10)
      range2 = range(3, 7, 4, 15)
      refute left_in_right?(range1, range2)
    end

    test "returns false if range 1 ends before range 2 same line" do
      range1 = range(1, 5, 1, 10)
      range2 = range(1, 11, 1, 15)
      refute left_in_right?(range1, range2)
    end
  end

  describe "sort_ranges_widest_to_narrowest/1" do
    test "sorts ranges" do
      ranges = [
        range(1, 5, 1, 10),
        range(1, 5, 1, 5),
        range(0, 0, 3, 10),
        range(1, 1, 2, 15),
        range(1, 4, 1, 20),
        range(1, 3, 2, 10)
      ]

      expected = [
        range(0, 0, 3, 10),
        range(1, 1, 2, 15),
        range(1, 3, 2, 10),
        range(1, 4, 1, 20),
        range(1, 5, 1, 10),
        range(1, 5, 1, 5)
      ]

      assert sort_ranges_widest_to_narrowest(ranges) == expected
    end
  end

  describe "increasingly_narrowing?/1" do
    test "returns true if only one range" do
      ranges = [
        range(0, 0, 3, 10)
      ]

      assert increasingly_narrowing?(ranges)
    end

    test "returns true if ranges are increasingly narrowing" do
      ranges = [
        range(0, 0, 3, 10),
        range(1, 1, 2, 15),
        range(1, 3, 2, 10),
        range(1, 4, 1, 20),
        range(1, 5, 1, 10),
        range(1, 5, 1, 5)
      ]

      assert increasingly_narrowing?(ranges)
    end

    test "returns false if order is broken" do
      ranges = [
        range(0, 0, 3, 10),
        range(1, 1, 3, 11)
      ]

      refute increasingly_narrowing?(ranges)
    end
  end

  describe "union/2" do
    test "right in left" do
      left = range(1, 1, 4, 10)
      right = range(2, 5, 3, 5)

      expected = left

      assert union(left, right) == expected
      assert union(right, left) == expected
    end

    test "right in left same line" do
      left = range(1, 1, 1, 10)
      right = range(1, 5, 1, 5)

      expected = left

      assert union(left, right) == expected
      assert union(right, left) == expected
    end

    test "right equal left" do
      left = range(1, 1, 2, 10)
      right = left

      expected = left

      assert union(left, right) == expected
    end

    test "overlap" do
      left = range(1, 1, 3, 10)
      right = range(2, 5, 4, 15)

      expected = range(1, 1, 4, 15)

      assert union(left, right) == expected
      assert union(right, left) == expected
    end

    test "overlap same line" do
      left = range(1, 1, 1, 10)
      right = range(1, 5, 1, 15)

      expected = range(1, 1, 1, 15)

      assert union(left, right) == expected
      assert union(right, left) == expected
    end

    test "overlap same line one column" do
      left = range(1, 1, 1, 10)
      right = range(1, 10, 1, 15)

      expected = range(1, 1, 1, 15)

      assert union(left, right) == expected
      assert union(right, left) == expected
    end

    test "raises if ranges do not intersect" do
      left = range(1, 1, 2, 5)
      right = range(3, 1, 4, 1)

      assert_raise ArgumentError, "no intersection", fn ->
        union(left, right)
      end

      assert_raise ArgumentError, "no intersection", fn ->
        union(right, left)
      end
    end

    test "raises if ranges do not intersect same line" do
      left = range(1, 1, 1, 5)
      right = range(1, 8, 1, 10)

      assert_raise ArgumentError, "no intersection", fn ->
        union(left, right)
      end

      assert_raise ArgumentError, "no intersection", fn ->
        union(right, left)
      end
    end
  end

  describe "intersection/2" do
    test "right in left" do
      left = range(1, 1, 4, 10)
      right = range(2, 5, 3, 5)

      expected = right

      assert intersection(left, right) == expected
      assert intersection(right, left) == expected
    end

    test "right in left same line" do
      left = range(1, 1, 1, 10)
      right = range(1, 5, 1, 5)

      expected = right

      assert intersection(left, right) == expected
      assert intersection(right, left) == expected
    end

    test "right equal left" do
      left = range(1, 1, 2, 10)
      right = left

      expected = left

      assert intersection(left, right) == expected
    end

    test "overlap" do
      left = range(1, 1, 3, 10)
      right = range(2, 5, 4, 15)

      expected = range(2, 5, 3, 10)

      assert intersection(left, right) == expected
      assert intersection(right, left) == expected
    end

    test "overlap same line" do
      left = range(1, 1, 1, 10)
      right = range(1, 5, 1, 15)

      expected = range(1, 5, 1, 10)

      assert intersection(left, right) == expected
      assert intersection(right, left) == expected
    end

    test "overlap same line one column" do
      left = range(1, 1, 1, 10)
      right = range(1, 10, 1, 15)

      expected = range(1, 10, 1, 10)

      assert intersection(left, right) == expected
      assert intersection(right, left) == expected
    end

    test "raises if ranges do not intersect" do
      left = range(1, 1, 2, 5)
      right = range(3, 1, 4, 1)

      assert_raise ArgumentError, "no intersection", fn ->
        intersection(left, right)
      end

      assert_raise ArgumentError, "no intersection", fn ->
        intersection(right, left)
      end
    end

    test "raises if ranges do not intersect same line" do
      left = range(1, 1, 1, 5)
      right = range(1, 8, 1, 10)

      assert_raise ArgumentError, "no intersection", fn ->
        intersection(left, right)
      end

      assert_raise ArgumentError, "no intersection", fn ->
        intersection(right, left)
      end
    end
  end

  describe "merge_ranges_lists/2" do
    test "equal length, 2 in 1" do
      range_1 = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4)
      ]

      range_2 = [
        range(1, 1, 5, 5),
        range(3, 1, 3, 5)
      ]

      expected = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4),
        range(3, 1, 3, 5)
      ]

      assert merge_ranges_lists(range_1, range_2) == expected
    end

    test "equal length, 1 in 2" do
      range_1 = [
        range(1, 1, 5, 5),
        range(3, 1, 3, 5)
      ]

      range_2 = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4)
      ]

      expected = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4),
        range(3, 1, 3, 5)
      ]

      assert merge_ranges_lists(range_1, range_2) == expected
    end

    test "equal length, ranges intersect" do
      range_1 = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4)
      ]

      range_2 = [
        range(1, 1, 5, 5),
        range(2, 5, 4, 8)
      ]

      expected = [
        range(1, 1, 5, 5),
        # union
        range(2, 2, 4, 8),
        # preferred from range_1
        range(2, 2, 4, 4)
      ]

      assert merge_ranges_lists(range_1, range_2) == expected
    end

    test "equal length, ranges intersect, last range_2 wider than range_1" do
      range_1 = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4),
        range(3, 6, 3, 8)
      ]

      range_2 = [
        range(1, 1, 5, 5),
        range(2, 5, 4, 8),
        range(2, 6, 4, 8)
      ]

      expected = [
        range(1, 1, 5, 5),
        # union
        range(2, 2, 4, 8),
        # preferred from range_1
        range(2, 2, 4, 4),
        # intersection of range_2 and range_1
        range(2, 6, 4, 4),
        # last range_1 range
        range(3, 6, 3, 8)
      ]

      assert merge_ranges_lists(range_1, range_2) == expected
    end

    test "ranges intersect, last range_2 wider than range_1" do
      range_1 = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4)
      ]

      range_2 = [
        range(1, 1, 5, 5),
        range(2, 5, 4, 8),
        range(2, 6, 4, 8)
      ]

      expected = [
        range(1, 1, 5, 5),
        # union
        range(2, 2, 4, 8),
        # preferred from range_1
        range(2, 2, 4, 4),
        # intersection of range_2 and range_1
        range(2, 6, 4, 4)
      ]

      assert merge_ranges_lists(range_1, range_2) == expected
    end

    test "raises if range list do not start with the same range" do
      range_1 = [
        range(2, 2, 4, 4),
        range(1, 1, 5, 5)
      ]

      range_2 = [
        range(1, 1, 3, 3),
        range(2, 2, 2, 2)
      ]

      assert_raise ArgumentError, fn ->
        merge_ranges_lists(range_1, range_2)
      end
    end

    test "raises if range_1 is not increasingly narrowing" do
      range_1 = [
        range(0, 0, 10, 10),
        range(2, 2, 4, 4),
        range(1, 1, 5, 5)
      ]

      range_2 = [
        range(0, 0, 10, 10),
        range(1, 1, 3, 3),
        range(2, 2, 2, 2)
      ]

      assert_raise ArgumentError, fn ->
        merge_ranges_lists(range_1, range_2)
      end
    end

    test "raises if range_2 is not increasingly narrowing" do
      range_1 = [
        range(0, 0, 10, 10),
        range(1, 1, 5, 5),
        range(2, 2, 4, 4)
      ]

      range_2 = [
        range(0, 0, 10, 10),
        range(2, 2, 2, 2),
        range(1, 1, 3, 3)
      ]

      assert_raise ArgumentError, fn ->
        merge_ranges_lists(range_1, range_2)
      end
    end

    test "handles equal ranges" do
      range_1 = [range(1, 1, 5, 5)]
      range_2 = [range(1, 1, 5, 5)]

      assert merge_ranges_lists(range_1, range_2) == [range(1, 1, 5, 5)]
    end

    test "handles one empty range" do
      range_1 = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4)
      ]

      range_2 = [range(1, 1, 5, 5)]

      expected = [
        range(1, 1, 5, 5),
        range(2, 2, 4, 4)
      ]

      assert merge_ranges_lists(range_1, range_2) == expected
    end
  end
end
